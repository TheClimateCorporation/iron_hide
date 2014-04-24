# IronHide

[![Gem Version](https://badge.fury.io/rb/iron_hide.svg)](http://badge.fury.io/rb/iron_hide)
[![Build Status](https://travis-ci.org/TheClimateCorporation/iron_hide.svg?branch=master)](https://travis-ci.org/TheClimateCorporation/iron_hide)
[![Code Climate](https://codeclimate.com/github/TheClimateCorporation/iron_hide.png)](https://codeclimate.com/github/TheClimateCorporation/iron_hide)

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
      ],

      "uuid" : "some-uniq-vals-here"
    }
  ]
```

The language enables a context-aware attribute-based access control (ABAC) authorization model. The language allows references to the `user` and `resource` objects. The library (i.e., `IronHide`) should guarantee that it is able to parse the attributes of these objects (e.g., `user::attribute::nested_attribute`), while maintaining immutability of the object itself.

The policy language was heavily inspired by the AWS IAM policies. For an
overview of this way of specifying authorization, see
(the Amazon docs located
here)[http://docs.aws.amazon.com/IAM/latest/UserGuide/PoliciesOverview.html].

#### Resource

The resource to which the rule applies. These should be namespaced properly,
since multiple applications may share resources. This resource should represent a generic name that any authorizing service can understand.
Please note that currently the resource specification must be either a "user" or
the key "resource", "user", or a string in the form of "word::word(::word)+"

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

#### UUIDs

IronHide takes an incredibly non opinionated approach as to how you store your
documents. We don't depend on resources having any ID, but having a primary key
for each resource does make debugging the resources responsible for allowing or
denying an action much easier. We just ask that you supply a string "uuid"
parameter for a rule if you would like meaningful logging during development.
This can be a randomly generated uuid, or if you're just storing your rules in a
flat file, incrementing an integer string is just fine too.

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
  c.namespace = 'com::myproject' # Default 'com::IronHide'

  # See Memoizing below
  c.memoize = true # Default
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
      ],
      "uuid" : "aaaa-bbbb-cccc-dddd"
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

### Attribute Memoization

Each time `::can?` or `::authorize!` is called, 0 or more rules are evaluated.
Each of these rules could depend on the evaluation of an unbounded number of
expressions.

In the last example of the previous section, the `:id` attribute of a user must
match the  `:manager_id` attribute of a resource. We can imagine the case where
the method call, `resource.manager_id` could potentially be expensive (e.g.,
it's not a simple DB attribute and requires a complex SQL query).

Memoization caches the method call, `resource.manager_id`, so that subsquent
rules that attribute do not repeat the call. Here is a simple example where two
rules need to be evaluated for a single action, `read` and memoization can
improve performance.

```javascript
[
  {
    "resource": "namespace::User",
    "action": ["read"],
    "description": "Allow users read users",
    "effect": "allow",
    "conditions": [
      {
        "equal": {
          "user::id": ["resource::id", "resource::manager_id"]
        }
      }
    ],
    "uuid" : "aaaa-bbbb-cccc-dddd"
  },
  {
    "resource": "namespace::User",
    "action": ["read", "manage"],
    "description": "Allow users to read and manage users",
    "effect": "allow",
    "conditions": [
      {
        "equal": {
          "user::id": ["resource::manager_id"]
        }
      }
    ],
    "uuid" : "eeee-ffff-gggg-hhhh"
  }
]
```



### Adapters

IronHide works with rules defined in the canonical JSON language. The storage back-end is abstracted through the use of adapters.

An available adapter type must be specified in a configuration file, which gets loaded with the application at start time.

The default adapter is the `File Adapter`.

#### File Adapter

The File adapter allows rules to be written into a flat file. See `spec/rules.json` for an example.


#### Logging

One of the most difficult pieces of debugging authorization logic is determining
which rule is responsible for the authorization decision. To enable easy
debugging, set the level in the configuration.
````
IronHide.config do |c|
  c.logger.level = Logger::DEBUG
end
````

The application will now output two pieces of information: The uuids for all
matching rules, and the specific rule that resulted in the authorization
decision or a "No rule matched" statement.

#### CouchDB Adapter

See: https://github.com/TheClimateCorporation/iron_hide-storage-couchdb_adapter

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
- Admin interface for modifying policies



