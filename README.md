# Luwa App - AI-Integrated F&B Management System

**Version:** 1.0.0
**Created:** February 6, 2026

## 📖 Description

Luwa App adalah sistem manajemen bisnis F&B (Food & Beverage) yang terintegrasi dengan AI Co-Pilot. Aplikasi ini memungkinkan owner bisnis untuk mengelola outlet dengan bantuan AI yang cerdas dan proaktif.

## 🎯 Features

- **POS System** - Point of Sale untuk kasir
- **Back Office** - Library, Inventory, HPP, Reports, Analytics
- **Kitchen Display** - Sistem display dapur
- **Customer App** - Self-order untuk customer
- **Online Food** - Integrasi dengan platform online delivery
- **Luwa AI** - Business Co-Pilot dengan Trust Level system (0-3)

## 🏗️ Tech Stack

- **Frontend:** Flutter 3.38.7 (Dart 3.10.7)
- **Backend:** Supabase (PostgreSQL + Edge Functions)
- **AI Engine:** DeepSeek API
- **State Management:** Riverpod
- **UI:** Material Design 3 + Google Fonts

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart        # Environment configuration
│   │   └── app_constants.dart     # App-wide constants
│   ├── models/                    # Data models
│   ├── repositories/              # Data repositories
│   ├── services/                  # Business logic services
│   │   └── ai/                    # AI-specific services
│   └── providers/                 # State providers
│       └── ai/                    # AI-specific providers
├── pos/                           # POS app module
│   └── ai/                        # POS AI features
├── backoffice/                    # Back Office module
│   └── ai/                        # Back Office AI features
├── shared/                        # Shared components
│   ├── widgets/                   # Reusable widgets
│   ├── themes/                    # Theme configuration
│   │   └── app_theme.dart
│   └── utils/                     # Utility functions
│       ├── format_utils.dart      # Formatting utilities
│       └── validators.dart        # Form validators
└── main.dart                      # App entry point
```

## 🗄️ Database Schema

Total: **26 tables**
- **21 core tables:** outlets, profiles, products, orders, ingredients, recipes, stock_movements, purchase_orders, shifts, customers, discounts, dll.
- **5 AI tables:**
  - `ai_trust_settings` - Trust level configuration
  - `ai_conversations` - Chat conversations
  - `ai_messages` - Chat messages
  - `ai_action_logs` - AI action history
  - `ai_insights` - Proactive insights

## 🤖 AI Features

### Trust Levels
- **Level 0 (Inform):** AI hanya memberi info
- **Level 1 (Suggest):** AI beri saran + minta konfirmasi
- **Level 2 (Auto):** AI jalankan otomatis + notify
- **Level 3 (Silent):** AI jalankan full auto (silent)

### AI Capabilities
- Sales analysis & reporting
- Stock monitoring & alerts
- Demand forecasting
- Auto stock adjustment
- Purchase order creation
- Pricing recommendations
- Anomaly detection
- Performance insights

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.38.7 or higher
- Dart SDK 3.10.7 or higher
- Supabase account
- DeepSeek API key

### Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure environment:**
   - Update `.env` with your Supabase credentials
   - DeepSeek API key already configured

3. **Run the app:**
   ```bash
   flutter run
   ```

## 📝 Environment Variables

Edit `.env` file in project root:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# DeepSeek AI Configuration
DEEPSEEK_API_KEY=your-deepseek-api-key-here

# App Configuration
APP_NAME=Luwa App
APP_VERSION=1.0.0
ENVIRONMENT=development
```

## 📋 Development Phases

- [x] **Phase 0:** Foundation & AI Setup
- [ ] **Phase 1:** POS - Kasir
- [ ] **Phase 2:** Back Office - Library & Admin
- [ ] **Phase 3:** Back Office - Inventory & HPP
- [ ] **Phase 4:** Back Office - Reports & Analytics
- [ ] **Phase 5:** Kitchen Display
- [ ] **Phase 6:** Customer Self-Order
- [ ] **Phase 7:** Online Food Integration
- [ ] **Phase 8:** AI Enhancements

## 🎨 Design System

### Colors
- **Primary:** Indigo (#6366F1)
- **Secondary:** Emerald (#10B981)
- **Accent:** Amber (#F59E0B)
- **AI:** Purple (#8B5CF6)

### Typography
- **Font Family:** Inter (via Google Fonts)
- **Scales:** Display, Headline, Title, Body, Label

## 📚 Documentation

See `../LUWA_APP_AI_ENGINE_ADDENDUM.md` for complete blueprint and architecture documentation.

## 🔐 Security

- API keys stored in `.env` (not committed to git)
- Supabase Row Level Security (RLS) enabled
- AI actions logged permanently
- Trust level system prevents unauthorized actions

## 📄 License

Proprietary - All rights reserved

---

**Luwa App** - AI Business Co-Pilot for F&B Industry
