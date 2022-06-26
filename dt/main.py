import torch

from dt.decision_transformer_atari import GPT, GPTConfig

vocab_size = 4
block_size = 90
model_type = "reward_conditioned"
timesteps = 2654

mconf = GPTConfig(
    vocab_size,
    block_size,
    n_layer=6,
    n_head=8,
    n_embd=128,
    model_type=model_type,
    max_timestep=timesteps,
)
model = GPT(mconf)

checkpoint_path = "checkpoints/Breakout_123.pth"  # or Pong, Qbert, Seaquest
checkpoint = torch.load(checkpoint_path, torch.device("cpu"))
model.load_state_dict(checkpoint)
