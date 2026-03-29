local RewardsCatalog = {}

export type MoneyReward = {
	timeMinutes: number,
	rewardType: "Money",
	amount: number,
}

export type BrainrotReward = {
	timeMinutes: number,
	rewardType: "Brainrot",
	rarity: string,
}

export type RewardEntry = MoneyReward | BrainrotReward

RewardsCatalog.CYCLE_DURATION_SECONDS = 86400

RewardsCatalog.Rewards = {
	{ timeMinutes = 1, rewardType = "Money", amount = 200 },
	{ timeMinutes = 5, rewardType = "Money", amount = 2000 },
	{ timeMinutes = 10, rewardType = "Money", amount = 50000 },
	{ timeMinutes = 15, rewardType = "Money", amount = 100000 },
	{ timeMinutes = 20, rewardType = "Brainrot", rarity = "Epic" },
	{ timeMinutes = 30, rewardType = "Money", amount = 1000000 },
	{ timeMinutes = 40, rewardType = "Money", amount = 5000000 },
	{ timeMinutes = 50, rewardType = "Money", amount = 50000000 },
	{ timeMinutes = 60, rewardType = "Brainrot", rarity = "Legendary" },
} :: { RewardEntry }

RewardsCatalog.REWARD_COUNT = #RewardsCatalog.Rewards

return RewardsCatalog
