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
### Local iteration 

Review the usage options to speed up development iterations for
BuildBot.

The "--stdout" option allows one to easily test the output by printing
to standard output (stdout).

The "--pipelines" option allows one to adjust the pipelines processed.

```
Usage: build_bot.rb [options]
    -s, --stdout                     Send output to stdout
    -p, --pipelines x,y,z            Pipeline list to process

```
# Usage
```
cp .env.sample .env
```
Open the .env file and fill out the required parameters

```
ruby build_bot.rb

```
