# ActiveForce

A ruby gem to interact with [SalesForce][1] as if it were Active Record. It
uses [Restforce][2] to interact with the API, so it is fast and stable.

### Beyond Finance Fork

This version is forked from the work done by
https://github.com/heroku/active_force which was in turn forked from
https://github.com/ionia-corporation/active_force.
It includes upgrades for Rails 7, as
well as additional functionality.

## Installation

Add this line to your application's `Gemfile`:

    gem 'active_force', github: "Beyond-Finance/active_force"

And then execute:

    $ bundle


## Setup credentials

[Restforce][2] is used to interact with the API, so you will need to setup
environment variables to set up credentials.

    SALESFORCE_USERNAME       = your-email@gmail.com
    SALESFORCE_PASSWORD       = your-sfdc-password
    SALESFORCE_SECURITY_TOKEN = security-token
    SALESFORCE_CLIENT_ID      = your-client-id
    SALESFORCE_CLIENT_SECRET  = your-client-secret

You might be interested in [dotenv-rails][3] to set up those in development.

Also, you may specify which client to use as a configuration option, which is useful
when having to reauthenticate utilizing oauth.

```ruby
ActiveForce.sfdc_client = Restforce.new(
  oauth_token:         current_user.oauth_token,
  refresh_token:       current_user.refresh_token,
  instance_url:        current_user.instance_url,
  client_id:           SALESFORCE_CLIENT_ID,
  client_secret:       SALESFORCE_CLIENT_SECRET
)
```

## Usage

```ruby
class Medication < ActiveForce::SObject

  field :name,             from: 'Name'

  field :max_dossage  # defaults to "Max_Dossage__c"
  field :updated_from

  ##
  # You can cast field value using `as`
  # field :address_primary_active, from: 's360a__AddressPrimaryActive__c', as: :boolean
  #
  # Available options are :boolean, :int, :double, :percent, :date, :datetime, :string, :base64,
  # :byte, :ID, :reference, :currency, :textarea, :phone, :url, :email, :combobox, :picklist,
  # :multipicklist, :anyType, :location, :compound

  ##
  # Table name is inferred from class name.
  #
  # self.table_name = 'Medication__c' # default one.

  ##
  # Validations
  #
  validates :name, :login, :email, presence: true

  # Use any validation from active record.
  # validates :text, length: { minimum: 2 }
  # validates :text, format: { with: /\A[a-zA-Z]+\z/, message: "only allows letters" }
  # validates :size, inclusion: { in: %w(small medium large),
  #   message: "%{value} is not a valid size" }

  ##
  # Defaults
  #
  # Set a default on any field using `default`.
  field :name,             from: 'Name', default: -> { 'default_name' }

  ##
  # Callbacks
  #
  before_save :set_as_updated_from_rails

  # Supported callbacks include :build, :create, :update, :save, :destroy

  private

  def set_as_updated_from_rails
    self.updated_from = 'Rails'
  end

end
```

Altenative you can try the generator. (requires setting up the connection)

    rails generate active_force:model Medication__c

The model generator also supports an optional namespace which will add a namespace to the generated model

    rails generate active_force:model Medication__c SomeNamespace

### Associations

#### Has Many

```ruby
class Account < ActiveForce::SObject
  has_many :pages

  # Use optional parameters in the declaration.

  has_many :medications,
    scoped_as: ->{ where("Discontinued__c > ? OR Discontinued__c = ?", Date.today.strftime("%Y-%m-%d"), nil) }

  has_many :today_log_entries,
    model: 'DailyLogEntry',
    scoped_as: ->{ where(date: Time.now.in_time_zone.strftime("%Y-%m-%d")) }

  has_many :labs,
    scoped_as: ->{ where("Category__c = 'EMR' AND Date__c <> NULL").order('Date__c DESC') }

end
```

#### Has One

```ruby
class Car < ActiveForce::SObject
  has_one :engine, model: 'CarEngine'
  has_one :driver_seat, model: 'Seat', scoped_as: -> { where(can_access_steering_wheel: true).order('Position ASC') }
end
```

#### Belongs to

```ruby
class Page < ActiveForce::SObject
  field :account_id,           from: 'Account__c'

  belongs_to :account
end
```

### Querying

You can retrieve SObject from the database using chained conditions to build
the query.

```ruby
Account.where(web_enable: 1, contact_by: ['web', 'email']).limit(2)
#=> this will query "SELECT Id, Name, WebEnable__c
#                    FROM Account
#                    WHERE WebEnable__C = 1 AND ContactBy__c IN ('web','email')
#                    LIMIT 2
```

You can query using _NOT_ (negated conditions):

```ruby
Account.where.not(web_enable: 1)
#=> this will query "SELECT Id, Name...
#                    FROM Account
#                    WHERE NOT WebEnable__c = 1"
```

You can create _OR_ queries:

```ruby
Account.where(contact_by: 'web').or(Account.where(contact_by: 'email'))
#=> this will query "SELECT Id, Name...
#                    FROM Account
#                    WHERE (contact_by__c = 'web')
#                    OR (contact_by__c = 'email')"
```

It is also possible to eager load associations:

```ruby
Comment.includes(:post)
```

It is possible to eager load multi level associations

In order to utilize multi level eager loads, the API version should be set to 58.0 or higher when instantiating a Restforce client 

```ruby
Restforce.new({api_version: '58.0'})
```

Examples:

```ruby
Comment.includes(post: :owner)
Comment.includes({post: {owner: :account}})
```

### Aggregates

Summing the values of a column:
```ruby
Transaction.where(offer_id: 'ABD832024').sum(:amount)
#=> This will query "SELECT SUM(Amount__c) 
#                    FROM Transaction__c 
#                    WHERE offer_id = 'ABD832024'"
```

#### Decorator

You can specify a `self.decorate(records)` method on the class, which will be called once with
the Restforce API results passed as the only argument. This allows you to decorate the results in one pass
through method, which is helpful if you need to bulk modify the returned API results and
don't want to incur any N+1 penalties. You must return the new altered array from
the decorate method.

```ruby
class Account < ActiveForce::SObject

  ##
  # Decorator
  #
  def self.decorate account_records
    # Perform other API call once for all account_records ids
    other_things = OtherAPI.find_things_with_ids(account_records.map{ |a| a["Id"] } )
    account_records.map do |a|
      # Find other_thing that corresponds to the current account_record
      other_thing_for_account = other_things.detect{ |o| o["Id"] == a["Id"]}

      # make updates to each record
      a.merge_in_other_stuff(other_thing_for_account)
    end # the mapped array will be returned
  end
end

accounts = Account.where(web_enabled: 1).limit(2)
# This finds the records from the RestForce API, and then decorate all results
with data from another API, and will only query the other API once.
```

### Model generator

When using rails, you can generate a model with all the fields you have on your SFDC table by running:

    rails g active_force:model <table name>

### Composite

Salesforce's API provides various features for submitting multiple operations in a single request.  Below are the features that ActiveForce supports.  Note that the Restforce client also provides methods for using the [Composite](https://github.com/restforce/restforce#composite-api) and [Composite Batch](https://github.com/restforce/restforce#composite-batch-api) APIs.

#### sObject Trees

An [sObject Tree](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_composite_sobject_tree.htm) request creates one or more trees of the same root object type and their child records up to 5 levels deep.  Child records are those associated by `has_one` or `has_many`.  Note that this only creates new records; it does not update existing ones.

For example, this will create `Root`, `Child`, and `Leaf` records with the correct associations in a single API request.

```ruby
leaf = Leaf.new(some_field: 'text')

child1 = Child.new
child1.leaf = leaf # Child: has_one :leaf

child2 = Child.new

root = Root.new(is_something: true)
root.children = [child1, child2] # Root: has_many :children

Root.create_tree(root)
```

You can pass in a single model instance like above or you can pass in an array of them.

```ruby
result = Model.create_tree([model1, model2, model3])
result.success?
result.error_responses
```

`#success?` will be true if all requests succeeded (in this case there would be at most one request).  `#error_responses` will be an array of `Restforce::Mash`es of any failed [response bodies](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/responses_composite_sobject_tree.htm).

There is also a bang alternative `create_tree!` that will raise a `ActiveForce::Composite::FailedRequestError` if the request fails.

```ruby
Model.create_tree!([model1, model2, model3])
```

All create operations defined in a single request will either all succeed or all fail. A single request can create up to 200 total objects. If any tree has more than 200 objects or if there are more than 200 root objects, `create_tree` will raise a `ActiveForce::Composite::ExceedsLimitsError`. By default, if given more than 200 objects over any number of trees, it will raise the same error.  If you want to create more than 200 objects, you can pass the `allow_multiple_requests` option. This will batch trees in requests so that they stay under that 200 object limit.  This, however, does not guarantee that all trees will either fail or succeed together.

```ruby
Model.create_tree(instance, allow_multiple_requests: true)
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new pull request so we can talk about it.
6. Once accepted, please add an entry in the CHANGELOG and rebase your changes
   to squash typos or corrections.

 [1]: http://www.salesforce.com
 [2]: https://github.com/ejholmes/restforce
 [3]: https://github.com/bkeepers/dotenv

