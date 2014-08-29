# continuum-stager-api

Simple gem to assist users writing custom Continuum Stagers.
An example sinatra stager is available at:

https://github.com/apcera/sample-apps/tree/master/continuum-stager-api

## Usage

First create your Gemfile. The contents should be:

```ruby
source "https://rubygems.org"

gem "continuum-stager-api"
```

Then run `bundle install` to download and install the gem and its dependencies.

Now that your environment is setup, create a new file for your stager. We recommend "stager.rb".

Start off with the contents:

```ruby
#!/usr/bin/env ruby

require "bundler"
Bundler.setup

require "continuum-stager-api"

stager = Apcera::Stager.new

# Download the package from the staging coordinator.
# This is the code that requires staging!
puts "Downloading Package..."
stager.download

# Extract the package to the "app" directory.
puts "Extracting Package..."
stager.extract("app")

# Your custom staging logic goes here.
# This will be a set of commands to execute in order to stage
# your applications.

# Finish staging, this will upload your final package to the
# staging coordinator.
puts "Completed Staging..."
stager.complete
```

## Deploying

Deploying just requires you to run `apc stager create`.

```console
apc stager create mystager --start-command="./stager.rb" --staging=/apcera::ruby --pipeline
```

Now you can deploy apps using your stager with `apc app create`.

```console
apc app create someapp --staging=mystager --start
```

## License

The MIT License (MIT)

Copyright (c) 2014 Apcera

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
