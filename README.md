# 📱 GeoHunt – Graduation Project

## 🎯 Project Goal
The goal of this project is to develop a **mobile application in Flutter** that works as a digital version of geocaching.  
Players will search for “caches” displayed on a map, which can only be unlocked when they are within a specific distance.  
Each discovery will be logged in the database (user, time, location).  
Additionally, the app will include **AR mini-games** to make the experience more engaging and unique compared to traditional geocaching.  

---

## 🛠 Technologies
- **Flutter** – cross-platform mobile app framework (Android, iOS)  
- **Supabase** – database, user authentication, backend  
- **flutter_map** or **google_maps_flutter** – maps integration  
- **geolocator** – location tracking and distance calculation  
- **ar_flutter_plugin** – basic AR mini-games  
- **Provider / Riverpod** – state management  

---

## 📋 Core Features (MVP)
- 🗺 Map with marked caches (approximate position, ±20 m)  
- 👤 User authentication (Supabase Auth)  
- 🔓 Unlocking a cache when in proximity  
- 📝 Logging discoveries (user + date + time) in the database  
- 🏆 List of discoveries / player leaderboard  

---

## 🎮 Extra Features (optional)
- 🎲 AR mini-game (e.g., tap on an object, collect coins, simple quiz)  
- ➕ Users can create their own caches  
- 🎯 Different types of mini-games for different caches  

---

## 🗓 Timeline
- **Sep 15 – Sep 30** → Basic app (map + GPS logic)  
- **Oct 1 – Oct 15** → Supabase setup (login, database)  
- **Oct 16 – Oct 31** → Logging discoveries, player list  
- **Nov 1 – Nov 15** → First AR mini-game  
- **Nov 16 – Nov 30** → Feature extensions, testing  
- **Dec 1 – Dec 15** → Bug fixes, optimization, presentation preparation  
- **Early January 2026** → Final app + presentation for graduation  

---

## ✅ Deliverables
- 📱 Fully working mobile app (Android/iOS)  
- 📖 Project documentation  
- 🖥 Presentation for defense  

---
