# Supabase Configuration Setup

This guide will help you configure Supabase to match your web app.

## Quick Setup

### Step 1: Get Your Supabase Anon Key

You need the anon key from your web app's Supabase project. You can get it in one of these ways:

**Option A: From Web App's .env File**
1. Open your web app project: `F:\Projects\dish-genie-visions`
2. Look for a `.env` file in the root directory
3. Find the line: `VITE_SUPABASE_PUBLISHABLE_KEY=...`
4. Copy the value after the `=`

**Option B: From Supabase Dashboard**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (Project ID: `kqhufomrgvpagbziwwok`)
3. Go to **Settings** → **API**
4. Copy the **anon/public** key

### Step 2: Configure the Flutter App

You have three options to configure the anon key:

#### Option 1: Update Config File (Easiest)
1. Open `lib/config/supabase_config.dart`
2. Replace the empty string in `supabaseAnonKey` with your anon key:
   ```dart
   static const String supabaseAnonKey = 'your_anon_key_here';
   ```

#### Option 2: Environment Variables (Recommended for Production)
When building the app, pass the key:
```bash
flutter build apk --dart-define=VITE_SUPABASE_PUBLISHABLE_KEY=your_anon_key_here
```

#### Option 3: Firebase Remote Config (Best for Dynamic Updates)
1. Go to Firebase Console → Remote Config
2. Add a new parameter:
   - **Key**: `supabase_anon_key`
   - **Value**: Your anon key
3. Publish the changes

## Current Configuration

- **Supabase URL**: `https://kqhufomrgvpagbziwwok.supabase.co`
- **Project ID**: `kqhufomrgvpagbziwwok` (matches web app)
- **Functions Available**:
  - `chat-assistant` (AI Chat)
  - `generate-meal-plan` (AI Meal Planner)
  - `generate-recipe` (AI Recipe Generator)
  - `generate-grocery-list` (AI Grocery List)
  - `analyze-ingredients` (AI Scanner)

## Verification

After configuration, run the app and check the logs. You should see:
```
✅ Supabase initialized successfully
   URL: https://kqhufomrgvpagbziwwok.supabase.co
   Project: kqhufomrgvpagbziwwok (matches web app)
```

If you see errors about missing anon key, double-check your configuration.

## Troubleshooting

**Error: "Requested function was not found"**
- Make sure you're using the correct Supabase project (kqhufomrgvpagbziwwok)
- Verify the anon key matches the web app's key

**Error: "Supabase anon key not configured"**
- Check that you've set the key in one of the three methods above
- Verify the key is not empty

**Functions work on web but not mobile**
- Ensure both apps use the same Supabase project
- Verify the anon key is identical in both apps
