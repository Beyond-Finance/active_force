class Bangwhiz < ActiveForce::SObject

  field :id,                   from: 'Id'
  field :percent,              from: 'Percent_Label',  as: :percent, default: -> { 50.0 }

end
