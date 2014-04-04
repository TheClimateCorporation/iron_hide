# IronHide

_Experimenting with a new way to implement authorization._

Ironhide is an authorization library. It uses a simple, declarative language implemented in JSON.

For more details around the motivation for this project, see: http://eng.climate.com/2014/02/12/service-oriented-authorization-part-1/


## Installation

Add this line to your application's Gemfile:

    gem 'iron_hide'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install iron_hide

## Usage

### Rules Language

Authorization rules are JSON documents. Here is an example of a document:

```javascript
  [
    {
      // [String]
      "resource": "namespace::Test",

      // [Array<String>]
      "action": ["read", "write"],

      // [String]
      "description": "Something descriptive",

      // [String]
      "effect": "allow",

      // [Array<Object>]
      "conditions": [
        // All conditions must be met (logical AND)
        {
          "equal": {
            // The numeric value of the key must be equal to any value in the array (logical OR)
            "resource::manager_id": ["user::id"]
          }
        },
        {
          "not_equal": {
            "user::disabled": [true]
          }
        }
      ]
    }
  ]
```

The language enables an Attribute Based Access Control (ABAC) authorization model.

This means that the authorization language is aware of the context of the authorization request and the authorization decision is based upon evaluating that context.

#### Attribute Based Access Control

The language allows references to a `user` and a `resource`.


### Configuration

IronHide must be configured during application load time.

This is an example configuration that uses authorization rules defined in a JSON file.

```ruby
# config/application.rb
require 'iron_hide'

IronHide.config do |c|
  c.adapter   = :file

  # This can be one or more files
  c.json      = '/path/to/json/file'

  # This is helpful if you have multiple projects with similarly named
  # resources
  c.namespace = 'com::myproject'
end
```

### Public API

There are two ways to perform an authorization check. If you have used [CanCan](https://github.com/ryanb/cancan), then these should look familiar.

Given a very simple relational schema, with one table (`users`):

|    users   |
| ---------- |
|     id     |
| manager_id |

Given a rule like this:

```javascript
    {
      "resource": "namespace::User",
      "action": ["read", "manage"],
      "description": "Allow users and managers to read and manage users",
      "effect": "allow",
      "conditions": [
        {
          "equal": {
            // The user's ID must be equal to the resource's ID or the resource's manager's ID
            "user::id": ["resource::id", "resource::manager_id"]
          }
        }
      ]
    }
```

Authorize one user for "reading" another:

```ruby
current_user = User.find(2)
IronHide.authorize! current_user, :read, User.find(1)
#=> Raises an IronHide::Error if authorization fails
```

```ruby
current_user = User.find(2)
IronHide.can? current_user, :read, User.find(1)
#=> true
```

### Adapters

IronHide works with rules defined in the canonical JSON language. The storage back-end is abstracted through the use of adapters.

An available adapter type must be specified in a configuration file, which gets loaded with the application at start time.

At the moment, only the File(JSON) adapter is supported.

#### File Adapter

The File adapter allows rules to be written into a flat file. See `spec/rules.json` for an example.

## Contributing

`bundle install` to install dependencies
`rake` to run tests
`yard` to generation documentation

## TODO

- Write a more detailed language specification
- Better README
- Move configuration to a module outside the top-level namespace
- Support for additional back-ends

See README in `applications/gems`
