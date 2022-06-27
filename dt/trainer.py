"""
The MIT License (MIT) Copyright (c) 2020 Andrej Karpathy

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""
import os
from dataclasses import dataclass
from pathlib import Path

from dt.decision_transformer_atari import GPT

"""
Simple training loop; Boilerplate that could apply to any arbitrary neural network,
so nothing in this file really has anything to do with GPT specifically.
"""

import logging

logger = logging.getLogger(__name__)

from utils import sample
import atari_py
from collections import deque
import random
import cv2
import torch


@dataclass
class TrainerConfig:
    game: str
    seed: int
    max_timestep: int

    # optimization parameters
    batch_size = 64
    betas = (0.9, 0.95)
    grad_norm_clip = 1.0
    learning_rate = 3e-4
    max_epochs = 10
    weight_decay = 0.1  # only applied on matmul weights

    # learning rate decay params: linear warmup followed by cosine decay to 10% of original
    final_tokens = 260e9  # (at what point we reach 10% of original LR)
    lr_decay = False
    warmup_tokens = 375e6  # these two numbers come from the GPT-3 paper, but may not be good defaults elsewhere

    # checkpoint settings
    ckpt_path = None
    num_workers = 0  # for DataLoader


class Args:
    def __init__(self, game: str, seed: int):
        self.device = torch.device("cuda")
        self.seed = seed
        self.max_episode_length = 108e3
        self.game = game
        self.history_length = 4


class Trainer:
    def __init__(self, model: GPT, config: TrainerConfig):
        self.model = model
        self.config = config

        # take over whatever gpus are on the system
        self.device = "cpu"
        if torch.cuda.is_available():
            self.device = torch.cuda.current_device()
            self.model = torch.nn.DataParallel(self.model).to(self.device)

    def save_checkpoint(self):
        # DataParallel wrappers keep raw model object in .module attribute
        raw_model = self.model.module if hasattr(self.model, "module") else self.model
        logger.info("saving %s", self.config.ckpt_path)
        # torch.save(raw_model.state_dict(), self.config.ckpt_path)

    def get_returns(self, ret: float):
        self.model.train(False)
        args = Args(
            game=self.config.game.lower(),
            seed=self.config.seed,
        )
        env = Env(args)
        env.eval()

        T_rewards, T_Qs = [], []
        done = True
        for i in range(10):
            state = env.reset()
            # noinspection PyTypeChecker
            state = state.type(torch.float32)
            state = state.to(self.device).unsqueeze(0).unsqueeze(0)
            rtgs = [ret]
            # first state is from env, first rtg is target return, and first timestep is 0
            sampled_action = sample(
                self.model.module,
                state,
                1,
                temperature=1.0,
                sample=True,
                actions=None,
                rtgs=torch.tensor(rtgs, dtype=torch.long)
                .to(self.device)
                .unsqueeze(0)
                .unsqueeze(-1),
                timesteps=torch.zeros((1, 1, 1), dtype=torch.int64).to(self.device),
            )

            j = 0
            all_states = state
            actions = []
            reward_sum = 0
            while True:
                if done:
                    state, reward_sum, done = env.reset(), 0, False
                action = sampled_action.cpu().numpy()[0, -1]
                actions += [sampled_action]
                state, reward, done = env.step(action)
                reward_sum += reward
                j += 1

                if done:
                    T_rewards.append(reward_sum)
                    break

                state = state.unsqueeze(0).unsqueeze(0).to(self.device)

                all_states = torch.cat([all_states, state], dim=0)

                rtgs += [rtgs[-1] - reward]
                # all_states has all previous states and rtgs has all previous rtgs (will be cut to block_size in
                # utils.sample) timestep is just current timestep
                sampled_action = sample(
                    self.model.module,
                    all_states.unsqueeze(0),
                    1,
                    temperature=1.0,
                    sample=True,
                    actions=torch.tensor(actions, dtype=torch.long)
                    .to(self.device)
                    .unsqueeze(1)
                    .unsqueeze(0),
                    rtgs=torch.tensor(rtgs, dtype=torch.long)
                    .to(self.device)
                    .unsqueeze(0)
                    .unsqueeze(-1),
                    timesteps=(
                        min(j, self.config.max_timestep)
                        * torch.ones((1, 1, 1), dtype=torch.int64).to(self.device)
                    ),
                )
        env.close()
        eval_return = sum(T_rewards) / 10.0
        print("target return: %d, eval return: %d" % (ret, eval_return))
        self.model.train(True)
        return eval_return


class Env:
    def __init__(self, args: Args):
        self.device = args.device
        self.ale = atari_py.ALEInterface()
        self.ale.setInt("random_seed", args.seed)
        self.ale.setInt("max_num_frames_per_episode", args.max_episode_length)
        self.ale.setFloat("repeat_action_probability", 0)  # Disable sticky actions
        self.ale.setInt("frame_skip", 0)
        self.ale.setBool("color_averaging", False)
        path = (
            Path(atari_py.__file__).parents[1]
            / Path("AutoROM/roms")
            / Path(args.game).with_suffix(".bin")
        )
        assert path.exists(), "rom not found: %s" % path
        self.ale.loadROM(str(path))  # ROM loading must be done after setting options
        actions = self.ale.getMinimalActionSet()
        self.actions = dict((i, e) for i, e in zip(range(len(actions)), actions))
        self.lives = 0  # Life counter (used in DeepMind training)
        self.life_termination = (
            False  # Used to check if resetting only from loss of life
        )
        self.window = args.history_length  # Number of frames to concatenate
        self.state_buffer = deque([], maxlen=args.history_length)
        self.training = True  # Consistent with model training mode

    def _get_state(self):
        # noinspection PyUnresolvedReferences
        state = cv2.resize(
            self.ale.getScreenGrayscale(), (84, 84), interpolation=cv2.INTER_LINEAR
        )
        return torch.tensor(state, dtype=torch.float32, device=self.device).div_(255)

    def _reset_buffer(self):
        for _ in range(self.window):
            self.state_buffer.append(torch.zeros(84, 84, device=self.device))

    def reset(self):
        if self.life_termination:
            self.life_termination = False  # Reset flag
            self.ale.act(0)  # Use a no-op after loss of life
        else:
            # Reset internals
            self._reset_buffer()
            self.ale.reset_game()
            # Perform up to 30 random no-ops before starting
            for _ in range(random.randrange(30)):
                self.ale.act(0)  # Assumes raw action 0 is always no-op
                if self.ale.game_over():
                    self.ale.reset_game()
        # Process and return "initial" state
        observation = self._get_state()
        self.state_buffer.append(observation)
        self.lives = self.ale.lives()
        return torch.stack(list(self.state_buffer), 0)

    def step(self, action):
        # Repeat action 4 times, max pool over last 2 frames
        frame_buffer = torch.zeros(2, 84, 84, device=self.device)
        reward, done = 0, False
        for t in range(4):
            reward += self.ale.act(self.actions.get(action))
            if t == 2:
                frame_buffer[0] = self._get_state()
            elif t == 3:
                frame_buffer[1] = self._get_state()
            done = self.ale.game_over()
            if done:
                break
        observation = frame_buffer.max(0)[0]
        self.state_buffer.append(observation)
        # Detect loss of life as terminal in training mode
        if self.training:
            lives = self.ale.lives()
            if self.lives > lives > 0:  # Lives > 0 for Q*bert
                self.life_termination = not done  # Only set flag when not truly done
                done = True
            self.lives = lives
        # Return state, reward, done
        return torch.stack(list(self.state_buffer), 0), reward, done

    # Uses loss of life as terminal signal
    def train(self):
        self.training = True

    # Uses standard terminal signal
    def eval(self):
        self.training = False

    def action_space(self):
        return len(self.actions)

    # noinspection PyUnresolvedReferences
    def render(self):
        cv2.imshow("screen", self.ale.getScreenRGB()[:, :, ::-1])
        cv2.waitKey(1)

    def close(self):
        # noinspection PyUnresolvedReferences
        cv2.destroyAllWindows()
