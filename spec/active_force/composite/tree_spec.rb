# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree'

module ActiveForce
  module Composite
    RSpec.describe Tree do
      describe '#initialize' do
        let(:root) { CompositeSupport::Root.new }

        it 'assigns root' do
          expect(Tree.new(root).root).to eq(root)
        end

        it 'assigns default max_depth of 5' do
          expect(Tree.new(root).max_depth).to eq(5)
        end

        it 'assigns max_depth if given' do
          expect(Tree.new(root, max_depth: 3).max_depth).to eq(3)
        end

        it 'clamps minimum max_depth at 1' do
          expect(Tree.new(root, max_depth: -1).max_depth).to eq(1)
        end
      end

      describe '#request'
      describe '#object_count'
      describe '#assign_ids'
      describe '.build'
    end
  end
end
