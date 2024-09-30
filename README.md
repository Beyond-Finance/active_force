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

You can use Ranges to specify comparisons:

```ruby
Account.where(last_activity_date: Date.new(2023, 1, 1)...Date.new(2024, 1, 1))
       .where(annual_revenue: 1_000..)
#=> this will query "SELECT Id, Name...
#                    FROM Account
#                    WHERE (LastActivityDate >= 2023-01-01) AND (LastActivityDate < 2024-01-01)
#                    AND (AnnualRevenue >= 1000)
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

You can also use #select with a multi level #includes.

Examples:

```ruby
Comment.select(:body, post: [:title, :is_active]).includes(post: :owner)
Comment.select(:body, account: :owner_id).includes({post: {owner: :account}})
```

The Sobject name in the #select must match the Sobject in the #includes for the fields to be filtered.

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

### Bulk Jobs

For more information about usage and limits of the Salesforce Bulk API see the [docs][4].

Convenience class methods have been added to `ActiveForce::SObject` to make it possible to utilize the Salesforce Bulk API v2.0.
The methods are: `bulk_insert_all`, `bulk_update_all`, & `bulk_delete_all`.  They all expect input as an Array of attributes as a Hash:
```ruby
[
  { id: '11111111', attribute1: 'value1', attribute2: 'value2'},
  { id: '22222222', attribute1: 'value3', attribute2: 'value4'},
]
```
The attributes will be mapped back to what's expected on the SF side automatically. The response is a `ActiveForce::Bulk::JobResult` object
which can access `successful` & `failed` results, has some `stats`, and the original `job` object that was used to create and process the
Bulk job.

### Model generator

When using rails, you can generate a model with all the fields you have on your SFDC table by running:

    rails g active_force:model <table name>

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
 [4]: https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/bulk_api_2_0.htm

