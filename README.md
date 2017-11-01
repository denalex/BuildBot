This is a spike, it works.. but no tests yet. 
It is a bot that checks the build status and sends out slack notifications.

# Setup
Ruby is a prerequisite. Install supporting gems with the following:

```
gem install bundler
bundle install
```

### Rubocop - static code analysis
There’s a [Rubocop](https://rubocop.readthedocs.io)
[.rubocop.yml](.rubocop.yml) file containing settings which checks
that the ruby code meets the [Ruby
Syleguide](https://github.com/bbatsov/ruby-style-guide). The utility
will be installed through Bundler above. Execute Rubocop with the following:

```
rubocop
```

# Usage
```
cp .env.sample .env
```
Open the .env file and fill out the required parameters

```
ruby build_bot.rb

```
