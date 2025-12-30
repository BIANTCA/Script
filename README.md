---

🧠 Universal.lua — Roblox Universal Utility Module

Universal.lua is a modular Roblox Lua script that adds powerful character, movement, and visual utilities into any custom Rayfield GUI window.
It’s designed to be dropped into any exploit script as a plug-and-play extension that automatically builds full-featured Main and Tools tabs.


---

🚀 Features

🧍 Character Main

Noclip – Walk through walls and objects.

Infinite Jump – Jump infinitely in the air.

Anti Ragdoll – Prevent ragdoll physics from applying.

God Mode – Set infinite health and auto-recover.

No Fall Damage – Disable fall damage or knockdown states.

Anti Stun – Prevent forced stuns or platform stand.


🏃 Movement

WalkSpeed Control – Adjust player movement speed (16–300).

JumpPower Control – Adjust jump height (50–300).

Air Control – Maintain steering while airborne.

Climb Anywhere – Scale any surface by moving forward.

Auto Align to Ground – Automatically stand level on slopes.


👁️ Visual

Fullbright – Always bright daylight environment.

Highlight Players – Colored outlines for other players.

Tracers – Draw lines from your screen center to player positions.

Distance Labels – Display distance above each player’s head.

Outline World – Apply holographic outlines to all world parts.


🧰 Tools

Delete Tool – Click any object to delete it.

Bring Tool – Pull targeted objects toward your character.

Anti AFK – Prevent idle kick by auto-simulating user input.

Anti Kick / Ban – Intercept Kick and Ban remote calls.

Rejoin Server – Instantly teleport back into the same game.

Close GUI – Cleanly remove the entire Rayfield interface.



---

🧩 Example Usage

To load the Universal module inside your own Rayfield GUI script:

local Universal = loadstring(game:HttpGet("https://raw.githubusercontent.com/BIANTCA/Script/refs/heads/main/universal.lua"))()
Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)

Parameters:

Window → your existing Rayfield window instance

Rayfield → the Rayfield library reference

Players → game:GetService("Players")

RunService → game:GetService("RunService")


Once called, this function automatically creates:

Main tab — Character, Movement, and Visual utilities

Tools tab — Miscellaneous tools and anti-systems



---

🧩 Integration Example

If your GUI already defines a Rayfield window:

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
 Name = "My Custom GUI",
 LoadingTitle = "Rayfield Interface",
 LoadingSubtitle = "Powered by Universal.lua"
})

-- Import Universal
local Universal = loadstring(game:HttpGet("https://raw.githubusercontent.com/BIANTCA/Script/refs/heads/main/universal.lua"))()
Universal.CreateUniversalTab(Window, Rayfield, game:GetService("Players"), game:GetService("RunService"))


---

🧩 Notes

All toggles, sliders, and buttons are self-contained and automatically connect to the local player.

Safe to integrate with any other GUI or exploit script.

Works with both desktop and mobile executors that support Rayfield.



---

⚙️ Credits

Developed by BIANTCA
Designed for easy integration, customization, and extendability.

---
