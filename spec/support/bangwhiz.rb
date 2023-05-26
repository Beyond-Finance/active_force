class Bangwhiz < ActiveForce::SObject

  field :id,                   from: 'Id'
  field :name,                 from: 'Name'
  field :percent,              from: 'Percent_Label',  as: :percent, default: -> { 50.0 }

end
