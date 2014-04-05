# IronHide

[![Gem Version](https://badge.fury.io/rb/iron_hide.svg)](http://badge.fury.io/rb/iron_hide)
[![Build Status](https://travis-ci.org/TheClimateCorporation/iron_hide.svg?branch=master)](https://travis-ci.org/TheClimateCorporation/iron_hide)

_Experimenting with a new way to implement authorization._

IronHide is an authorization library. It uses a simple, declarative language implemented in JSON.

For more details around the motivation for this project, see: http://eng.climate.com/2014/02/12/service-oriented-authorization-part-1/

For a _tiny_ example, look here https://github.com/TheClimateCorporation/iron_hide_sample_app


## Installation

Add this line to your application's Gemfile:

    gem 'iron_hide', path: '/path/to/source'

And then execute:

    $ bundle install

Or build and install it yourself as:
    
    $ gem build '/path/to/iron_hide.gemspec'
    $ gem install iron_hide.gem

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

The language enables a context-aware attribute-based access control (ABAC) authorization model. The language allows references to the `user` and `resource` objects. The library (i.e., `IronHide`) should guarantee that it is able to parse the attributes of these objects (e.g., `user::attribute::nested_attribute`), while maintaining immutability of the object itself.

#### Resource

The resource to which the rule applies. These should be namespaced properly, since multiple applications may share resources.

#### Action

An array of Strings that specifies the set of actions to which the current rule applies.

Actions can be named anything you want and in Ruby/Rails these would typically be aligned with the instance methods for a class:

```ruby
class User
  # The 'delete' action
  def delete
    ...
  end

  # The 'charge' action
  def charge
    ...
  end
end
```

#### Description

A string that helps humans reading the rule JSON understand it more easily. It’s optional.

#### Effect

This is required. It is the effect a rule has when a user requests access to conduct an action to which the rule applies. It is either ‘allow’ or ‘deny’.

#### Evaluation of Rules

1. Default: Deny
2. Evaluate applicable policies
    - Match on: resource and action
3. Does policy exist for resource and action?
    - If no: Deny
    - Do any rules resolve to Deny?
        - If yes, Deny
        - If no, Do any rules resolve to Allow?
        - If yes, Allow
    - Else: Deny

**If access to a resource is not specifically allowed, authorization will default to DENY. This should make it easy to reason about: “A user was denied this request. I should create a rule that specifically allows access.”**

#### Conditions

Conditions are expressions that are evaluated to decide whether the effect of a particular rule should or should not apply. The expression semantics are dictated by the consuming application and the implementation of the library code that is used to communicate with and parse our rules.

This object is optional (i.e., the rule is always in effect). It is an array of objects to allow multiple of the same type of condition to be evaluated (e.g., `equal`, `not_equal`).

When creating a condition block, the name of each condition is specified, and there is at least one key-value pair for each condition.

**How conditions are evaluated:**

* A logical AND is applied to conditions within a condition block and to the keys with that condition.
* A logical OR is applied to the values of a single key.
* All conditions must be met (logical AND across all conditions) to return an allow or deny decision.

For example, here the agency_id of a resource must equal the agency_id of a user.

```javascript
// Condition
{
  "equal": {
    "resource::agency_id": ["user::agency_id"]
  }
}
```

The value of a key in a condition may be checked against multiple values. It must match at least one for the condition to hold.

```javascript
// Condition
{
  "equal": {
    "user::role_id": [1,2,3,4]
  }
}
```

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

- `bundle install` to install dependencies
- `rake` to run tests
- `yard` to generate documentation
- Pull requests, issues, comments are welcome

## Further Reading
- Service-Oriented Authorization blog posts: 
    - [Part 1](http://eng.climate.com/2014/02/12/service-oriented-authorization-part-1/)
    - [Part 2](http://eng.climate.com/2014/02/12/service-oriented-authorization-part-2/)
- [XACML(eXtensible Access Control Markup Language)](http://en.wikipedia.org/wiki/XACML)
- Amazon: [Access Policy Language](http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/AccessPolicyLanguage.html)

## TODO

- Write a more detailed language specification
- Better README
- Move configuration to a module outside the top-level namespace
- Support for additional back-ends
- Admin interface for modifying policies



