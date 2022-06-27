import numpy as np
import torch
import pandas as pd
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
    print("Loading checkpoint...")
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

    def get_rets():
        ret = 1
        while ret < 1e5:
            rets = list(trainer.get_returns(ret))
            yield ret, rets
            print(f"ret: {ret}, mean: {np.mean(rets)}, std: {np.std(rets)}")
            ret *= 2

    means = [
        dict(ret=ret, mean=np.mean(rets), std=np.std(rets)) for ret, rets in get_rets()
    ]

    df = pd.DataFrame.from_records(means)
    df.to_csv("rets.csv", index=False)


if __name__ == "__main__":
    main()
