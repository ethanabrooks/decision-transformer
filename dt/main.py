from pathlib import Path

import atari_py
import torch
from dollar_lambda import command

from dt.decision_transformer_atari import GPT, GPTConfig

from dt.trainer import Trainer, TrainerConfig


@command()
def main(
    game: str = "Breakout",
    seed: int = 0,
    block_size: int = 90,
    model_type: str = "reward_conditioned",
    n_layer: int = 6,
    n_head: int = 8,
    n_embd: int = 128,
    timesteps: int = 2654,
    vocab_size: int = 4,
):
    conf = GPTConfig(
        vocab_size,
        block_size,
        n_layer=n_layer,
        n_head=n_head,
        n_embd=n_embd,
        model_type=model_type,
        max_timestep=timesteps,
    )
    model = GPT(conf)
    checkpoint_path = f"checkpoints/{game}_123.pth"  # or Pong, Qbert, Seaquest
    checkpoint = torch.load(checkpoint_path)
    model.load_state_dict(checkpoint)

    trainer = Trainer(
        model,
        TrainerConfig(
            game=game,
            seed=seed,
            max_timestep=timesteps,
        ),
    )
    rets = trainer.get_returns(1.0)
    breakpoint()


if __name__ == "__main__":
    main()
