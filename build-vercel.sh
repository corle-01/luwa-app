#!/bin/bash
set -e

echo "📦 Installing Flutter..."

# Install Flutter if not exists
if [ ! -d "/vercel/.flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 /vercel/.flutter
fi

export PATH="/vercel/.flutter/bin:$PATH"

echo "🔧 Flutter version:"
flutter --version

echo "📥 Getting dependencies..."
flutter pub get

echo "🏗️  Building web app..."
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY

echo "✅ Build complete!"
