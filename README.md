This is a spike, it works.. but no tests yet. 
It is a bot that checks the build status and sends out slack notifications.

# Setup
Ruby is a prerequisite.

```
gem install bundler
bundle install
```

# Usage
```
cp .env.sample .env
```
Open the .env file and fill out the required parameters

```
ruby build_bot.rb

```
