game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 75
		humanoid.WalkSpeed = 16
	end)
end)
