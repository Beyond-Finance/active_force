# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree_builder'

module ActiveForce
  module Composite
    RSpec.describe TreeBuilder do
      let(:client) { instance_double(Restforce::Client, options: { api_version: '51.0' }) }
      let(:root_class) { CompositeSupport::Root }

      before do
        allow(client).to receive(:api_post).and_return(Restforce::Mash.new)
        ActiveForce.sfdc_client = client
      end

      describe '#commit' do
        it 'raises InvalidOperationError if called more than once' do
          builder = described_class.new(root_class)
          builder.commit
          expect { builder.commit }.to raise_error(InvalidOperationError, /committed/)
        end

        context 'with no roots' do
          it 'does not send any requests' do
            builder = described_class.new(root_class)
            builder.commit
            expect(client).not_to have_received(:api_post)
          end
        end

        context 'with single root' do
          it 'raises ExceedsLimitsError if tree has too many objects'
          it 'sends request with tree request body'
          it 'assigns ids on tree with response'
          context 'when successful' do
            it 'returns result'
          end
          context 'when there are errors' do
            it 'returns result with errors'
          end
          context 'when sending request raises' do
            it 'raises the error'
            it 'remains uncommitted'
          end
        end

        context 'with multiple roots' do
          context 'when multiple requests are not allowed' do
            it 'raises ExceedsLimitsError if any tree has too many objects'
            it 'raises ExceedsLimitsError if the sum of objects over all trees is too large'
            it 'sends request with combined tree request bodies'
            it 'assigns ids on all trees with response'
            context 'when successful' do
              it 'returns result'
            end
            context 'when there are errors' do
              it 'returns result with errors'
            end
            context 'when sending request raises' do
              it 'raises the error'
              it 'reamains uncommitted'
            end
          end

          context 'when multiple requests are allowed' do
            it 'raises ExceedsLimitsError if any tree has too many objects'
            context 'when all trees can fit in a single request' do
              it 'sends a single request with combined tree request bodies'
              it 'assigns ids on all trees with response'
            end

            context 'when trees cannot fit in a single request' do
              it 'sends batched requests all under maximum number of objects'
              it 'assigns ids to trees in each batch with the appropriate response'
            end

            context 'when all requests are successful' do
              it 'returns result'
            end

            context 'when some requests have errors' do
              it 'combines errors into a single result'
            end

            context 'when sending any request raises' do
              it 'raises the error'
              it 'remains uncommitted'
            end
          end
        end
      end

      describe '#commit!' do
        let(:builder) { described_class.new(root_class) }

        it 'calls #commit and returns result' do
          expected = TreeBuilder::Result.new([])
          allow(builder).to receive(:commit).and_return(expected)
          expect(builder.commit!).to eq(expected)
        end

        it 'raises FailedRequestError if result is unsuccessful' do
          message = 'test error message'
          response = Restforce::Mash.new(hasErrors: true, results: [{ message: message }])
          result = TreeBuilder::Result.new([response])
          allow(builder).to receive(:commit).and_return(result)
          expect { builder.commit! }.to raise_error(FailedRequestError, /#{message}/)
        end
      end

      describe '#add_roots' do
        let(:max_objects) { 2 }
        let(:builder) { described_class.new(root_class, max_objects: max_objects) }

        it 'raises ArgumentError if given an object that does not match the root class' do
          expect { builder.add_roots(Numeric.new) }.to raise_error(ArgumentError, /#{root_class}/)
        end

        it 'raises InvalidOperationError if instance has already committed' do
          builder.commit
          expect { builder.add_roots(root_class.new) }.to raise_error(InvalidOperationError, /committed/)
        end

        it 'does not keep duplicate roots' do
          root = root_class.new
          expect { builder.add_roots(*(max_objects + 1).times.map { root }) }
            .not_to raise_error(ExceedsLimitsError)
        end

        context 'when multiple requests are not allowed' do
          it 'raises ExceedsLimitsError if number of roots would exceed max_objects' do
            expect { builder.add_roots(*(max_objects + 1).times.map { root_class.new }) }
              .to raise_error(ExceedsLimitsError, /#{max_objects}/)
          end
        end

        context 'when multiple requests are allowed' do
          let(:builder) { described_class.new(root_class, max_objects: max_objects, allow_multiple_requests: true) }

          it 'does not raise ExceedsLimitsError if number of roots would exceed max_objects' do
            expect { builder.add_roots(*(max_objects + 1).times.map { root_class.new }) }
              .not_to raise_error(ExceedsLimitsError, /#{max_objects}/)
          end
        end
      end
    end
  end
end
