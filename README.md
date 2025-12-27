# Roblox Luau Basic Template (useless to read)

A simple and clean **Roblox Luau base code** example to help beginners understand the core structure of Roblox scripting using the Luau language.  
This template is ideal for learning, testing, or starting small Roblox projects.

## 🧠 About Luau

**Luau** is a fast, type-safe scripting language derived from **Lua 5.1**, optimized for the Roblox engine.  
It adds powerful features like:
- Gradual typing
- Performance improvements
- Enhanced memory safety
- Better tooling and analysis support

For full documentation, visit: [https://luau-lang.org](https://luau-lang.org)

## 🧩 Features

- Ready-to-use **LocalScript** and **ServerScript** examples  
- Organized and commented **Luau syntax** for readability  
- Demonstrates basic **Roblox API usage** (Players, Services, Events)  
- Clean code style and indentation  
- Beginner-friendly structure for new developers

## 📁 Folder Structure

Roblox-Luau-Basics/ │ ├── src/ │   ├── client/ │   │   └── main.client.lua │   ├── server/ │   │   └── main.server.lua │   └── shared/ │       └── utils.lua │ └── README.md

## 🚀 Example Code

### Client Script (`main.client.lua`)
```lua
-- Get the local player
local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("Hello, " .. player.Name .. "! Welcome to Roblox scripting.")

-- Detect keyboard input
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input)
 if input.KeyCode == Enum.KeyCode.Space then
  print("You pressed SPACE!")
 end
end)

Server Script (main.server.lua)

-- Server-side example
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
 print(player.Name .. " has joined the game.")
end)

Players.PlayerRemoving:Connect(function(player)
 print(player.Name .. " has left the game.")
end)
```

---

### ⚙️ How to Use

1. Open Roblox Studio.


2. Create a new Baseplate project.


3. Open Explorer → Insert a new Script or LocalScript.


4. Copy and paste the example code.


5. Click Play (F5) to run and test your script.

---

### 🧩 Recommended Setup

Roblox Studio (latest version)

Rojo (optional) for external editing and version control

VS Code with Luau language support

---

### 🧠 Tips for Beginners

Always test your code in Play Mode before publishing.

Use print() statements for debugging.

Organize your scripts into client, server, and shared folders.

Avoid heavy loops inside while true do — use events instead.

---

### 📜 License

This project is licensed under the MIT License – feel free to use, modify, and distribute with attribution.


---

### 💬 Contributing

Pull requests and improvements are welcome!
If you find a bug or want to add new examples, feel free to open an issue.
