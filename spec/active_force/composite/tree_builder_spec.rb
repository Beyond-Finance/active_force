# frozen_string_literal: true

require 'spec_helper'
require 'active_force/composite/tree'
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
        let(:request_path) { "composite/tree/#{root_class.table_name}" }
        let(:max_objects) { 4 }
        let(:builder) { described_class.new(root_class, max_objects: max_objects) }

        it 'sets builder as committed?' do
          builder.commit
          expect(builder.committed?).to be(true)
        end

        it 'raises InvalidOperationError if called more than once' do
          builder.commit
          expect { builder.commit }.to raise_error(InvalidOperationError, /committed/)
        end

        context 'with no roots' do
          it 'does not send any requests' do
            builder.commit
            expect(client).not_to have_received(:api_post)
          end
        end

        context 'with single root' do
          let(:root) { root_class.new }
          let(:tree_request) do
            { attributes: { type: root.class.table_name, referenceId: 'root1' } }
          end
          let(:tree) { instance_double(Tree, object_count: 1, request: tree_request, assign_ids: nil) }
          let(:response) do
            Restforce::Mash.new({ hasErrors: false, results: [{ id: 'id1', referenceId: 'root1' }] })
          end

          before do
            allow(Tree).to receive(:build).with(root).and_return(tree)
            allow(client).to receive(:api_post).and_return(response)
            builder.add_roots(root)
          end

          it 'raises ExceedsLimitsError if tree has too many objects' do
            allow(tree).to receive(:object_count).and_return(max_objects + 1)
            expect { builder.commit }.to raise_error(ExceedsLimitsError, /#{max_objects}/)
          end

          it 'sends request with tree request body' do
            builder.commit
            expect(client).to have_received(:api_post).with(request_path, { records: [tree_request] }.to_json).once
          end

          it 'assigns ids on tree with response' do
            builder.commit
            expect(tree).to have_received(:assign_ids).with(response)
          end

          context 'when successful' do
            it 'returns result' do
              expect(builder.commit.success?).to be(true)
            end
          end

          context 'when there are errors' do
            let(:errors) { [{ message: 'some error' }] }
            let(:response) do
              Restforce::Mash.new({ hasErrors: true, results: [{ referenceId: 'root1', errors: errors }] })
            end

            it 'returns result with errors' do
              result = builder.commit
              expect(result.success?).to be(false)
              expect(result.error_responses).to match_array([response])
            end
          end

          context 'when sending request raises' do
            let(:error) { StandardError.new('test error') }

            before { allow(client).to receive(:api_post).and_raise(error) }

            it 'raises the error and the builder remains uncommitted' do
              expect { builder.commit }.to raise_error(error)
              expect(builder.committed?).to be(false)
            end
          end
        end

        context 'with multiple roots' do
          let(:roots) { (max_objects - 1).times.map { root_class.new } }
          let(:requests) do
            roots.map.with_index { |r, i| { attributes: { type: r.class.table_name, referenceId: "ref#{i}" } } }
          end
          let(:trees) do
            roots.map.with_index do |_, i|
              instance_double(Tree, object_count: 1, request: requests[i], assign_ids: nil)
            end
          end

          before do
            trees.each_with_index { |tree, i| allow(Tree).to receive(:build).with(roots[i]).and_return(tree) }
            builder.add_roots(*roots)
          end

          context 'when multiple requests are not allowed' do
            let(:response) do
              results = roots.map.with_index { |_, i| { id: "id#{i}", referenceId: "ref#{i}" } }
              Restforce::Mash.new({ hasErrors: false, results: results })
            end

            before do
              allow(client).to receive(:api_post).and_return(response)
            end

            it 'raises ExceedsLimitsError if any tree has too many objects' do
              allow(trees.last).to receive(:object_count).and_return(max_objects + 1)
              expect { builder.commit }.to raise_error(ExceedsLimitsError, /A tree/i)
            end

            it 'raises ExceedsLimitsError if the sum of objects over all trees is too large' do
              allow(trees.last).to receive(:object_count).and_return(max_objects)
              expect { builder.commit }.to raise_error(ExceedsLimitsError, /#{max_objects} in one request/i)
            end

            it 'sends request with combined tree request bodies' do
              builder.commit
              expect(client).to have_received(:api_post).with(request_path, { records: requests }.to_json).once
            end

            it 'assigns ids on all trees with response' do
              builder.commit
              expect(trees).to all(have_received(:assign_ids).with(response))
            end
          end

          context 'when multiple requests are allowed' do
            let(:builder) { described_class.new(root_class, max_objects: max_objects, allow_multiple_requests: true) }

            it 'raises ExceedsLimitsError if any tree has too many objects' do
              allow(trees.last).to receive(:object_count).and_return(max_objects + 1)
              expect { builder.commit }.to raise_error(ExceedsLimitsError, /A tree/i)
            end

            context 'when all trees can fit in a single request' do
              let(:response) do
                results = roots.map.with_index { |_, i| { id: "id#{i}", referenceId: "ref#{i}" } }
                Restforce::Mash.new({ hasErrors: false, results: results })
              end

              before do
                allow(client).to receive(:api_post).and_return(response)
              end

              it 'sends a single request with combined tree request bodies' do
                builder.commit
                expect(client).to have_received(:api_post).with(request_path, { records: requests }.to_json).once
              end

              it 'assigns ids on all trees with response' do
                builder.commit
                expect(trees).to all(have_received(:assign_ids).with(response))
              end
            end

            context 'when trees cannot fit in a single request' do
              let(:responses) do
                roots.map.with_index do |_, i|
                  Restforce::Mash.new({ hasErrors: false, results: [{ id: "id#{i}", referenceId: "ref#{i}" }] })
                end
              end

              before do
                trees.each { |tree| allow(tree).to receive(:object_count).and_return(max_objects) }
                allow(client).to receive(:api_post).and_return(*responses)
              end

              it 'sends batched requests' do
                builder.commit
                expect(client).to have_received(:api_post).with(request_path, anything).exactly(trees.count)
                requests.each do |request|
                  expect(client).to have_received(:api_post).with(request_path, { records: [request] }.to_json)
                end
              end

              it 'assigns ids to trees in each batch with the appropriate response' do
                builder.commit
                trees.each_with_index { |tree, i| expect(tree).to have_received(:assign_ids).with(responses[i]) }
              end

              context 'when all requests are successful' do
                it 'returns result' do
                  expect(builder.commit.success?).to be(true)
                end
              end

              context 'when some requests have errors' do
                before do
                  responses.first.hasErrors = true
                  responses.last.hasErrors = true
                end

                it 'combines errors into a single result' do
                  result = builder.commit
                  expect(result.success?).to be(false)
                  expect(result.error_responses).to match_array([responses.first, responses.last])
                end
              end

              context 'when sending request raises' do
                let(:error) { StandardError.new('test error') }

                before do
                  allow(client).to receive(:api_post).and_raise(error)
                end

                it 'raises the error and builder remains uncommitted' do
                  expect { builder.commit }.to raise_error(error)
                  expect(builder.committed?).to be(false)
                end
              end
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
          expect { builder.add_roots(*(max_objects + 1).times.map { root }) }.not_to raise_error
        end

        context 'when multiple requests are not allowed' do
          it 'raises ExceedsLimitsError if number of roots would exceed max_objects' do
            expect { builder.add_roots(*(max_objects + 1).times.map { root_class.new }) }
              .to raise_error(ExceedsLimitsError, /#{max_objects}/)
          end
        end

        context 'when multiple requests are allowed' do
          let(:builder) { described_class.new(root_class, max_objects: max_objects, allow_multiple_requests: true) }

          it 'does not raise if number of roots would exceed max_objects' do
            expect { builder.add_roots(*(max_objects + 1).times.map { root_class.new }) }.not_to raise_error
          end
        end
      end
    end
  end
end
