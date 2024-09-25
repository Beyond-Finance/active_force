require 'spec_helper'

module ActiveForce
  describe SObject do
    let(:client){ double "client" }

    before do
      ActiveForce.sfdc_client = client
    end

    describe '.includes' do
      context 'belongs_to' do
        it 'queries the API for the associated record' do
          soql = Territory.includes(:quota).where(id: '123').to_s
          expect(soql).to eq "SELECT Id, Quota__c, Name, Quota__r.Bar_Id__c FROM Territory WHERE (Id = '123')"
        end

        it "queries the API once to retrieve the object and its related one" do
          response = [build_restforce_sobject({
            "Id"       => "123",
            "Quota__c" => "321",
            "Quota__r" => {
              "Bar_Id__c" => "321"
            }
          })]
          allow(client).to receive(:query).once.and_return response
          territory = Territory.includes(:quota).find "123"
          expect(territory.quota).to be_a Quota
          expect(territory.quota.id).to eq "321"
        end

        it "queries the API once to retrieve the object and its related one" do
          response = [build_restforce_sobject({
            "Id"       => "123",
            "Quota__c" => "321",
            "Quota__r" => {
              "Bar_Id__c" => "321"
            }
          })]
          allow(client).to receive(:query).once.and_return response
          territory = Territory.includes(:quota).find "123"
          expect(territory.quota).to be_a Quota
          expect(territory.quota.id).to eq "321"
        end

        context 'when nested select statement' do
          it 'formulates the correct SOQL query' do
            soql = Salesforce::Territory.select(:id, :quota_id, quota: :id).includes(:quota).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, QuotaId, QuotaId.Id FROM Territory WHERE (Id = '123')"
          end
        end

        context 'with namespaced SObjects' do
          it 'queries the API for the associated record' do
            soql = Salesforce::Territory.includes(:quota).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, QuotaId, WidgetId, QuotaId.Id FROM Territory WHERE (Id = '123')"
          end

          it "queries the API once to retrieve the object and its related one" do
            response = [build_restforce_sobject({
              "Id"       => "123",
              "QuotaId"  => "321",
              "WidgetId" => "321",
              "QuotaId" => {
                "Id" => "321"
              }
            })]
            allow(client).to receive(:query).once.and_return response
            territory = Salesforce::Territory.includes(:quota).find "123"
            expect(territory.quota).to be_a Salesforce::Quota
            expect(territory.quota.id).to eq "321"
          end

          context 'when the relationship table name is different from the actual table name' do
            it 'formulates the correct SOQL' do
              soql = Salesforce::Opportunity.includes(:owner).where(id: '123').to_s
              expect(soql).to eq "SELECT Id, OwnerId, AccountId, Business_Partner__c, Owner.Id FROM Opportunity WHERE (Id = '123')"
            end

            it "queries the API once to retrieve the object and its related one" do
              response = [build_restforce_sobject({
                "Id"       => "123",
                "OwnerId"  => "321",
                "AccountId"  => "432",
                "Owner" => {
                  "Id" => "321"
                }
              })]
              allow(client).to receive(:query).once.and_return response
              opportunity = Salesforce::Opportunity.includes(:owner).find "123"
              expect(opportunity.owner).to be_a Salesforce::User
              expect(opportunity.owner.id).to eq "321"
            end
          end

          context 'when the class name does not match the SFDC entity name' do
            let(:expected_soql) do
              "SELECT Id, QuotaId, WidgetId, WidgetId.Id FROM Territory WHERE (Id = '123')"
            end

            it 'queries the API for the associated record' do
              soql = Salesforce::Territory.includes(:widget).where(id: '123').to_s
              expect(soql).to eq expected_soql
            end

            it "queries the API once to retrieve the object and its related one" do
              response = [build_restforce_sobject({
                "Id"        => "123",
                "WidgetId"  => "321",
                "WidgetId" => {
                  "Id" => "321"
                }
              })]
              expected = expected_soql + ' LIMIT 1'
              allow(client).to receive(:query).once.with(expected).and_return response
              territory = Salesforce::Territory.includes(:widget).find "123"
              expect(territory.widget).to be_a Salesforce::Widget
              expect(territory.widget.id).to eq "321"
            end
          end

          context 'child to several parents' do
            it 'queries the API for associated records' do
              soql = Salesforce::Territory.includes(:quota, :widget).where(id: '123').to_s
              expect(soql).to eq "SELECT Id, QuotaId, WidgetId, QuotaId.Id, WidgetId.Id FROM Territory WHERE (Id = '123')"
            end

            it "queries the API once to retrieve the object and its assocations" do
              response = [build_restforce_sobject({
                "Id"       => "123",
                "QuotaId"  => "321",
                "WidgetId" => "321",
                "QuotaId" => {
                  "Id" => "321"
                },
                "WidgetId" => {
                  "Id" => "321"
                }
              })]
              allow(client).to receive(:query).once.and_return response
              territory = Salesforce::Territory.includes(:quota, :widget).find "123"
              expect(territory.quota).to be_a Salesforce::Quota
              expect(territory.quota.id).to eq "321"
              expect(territory.widget).to be_a Salesforce::Widget
              expect(territory.widget.id).to eq "321"
            end
          end
        end

        context 'when there is no associated record' do
          it "queries the API once to retrieve the object and its related one" do
            response = [build_restforce_sobject({
              "Id"       => "123",
              "Quota__c" => "321",
              "Quota__r" => nil
            })]
            allow(client).to receive(:query).once.and_return response
            territory = Territory.includes(:quota).find "123"
            expect(territory.quota).to be_nil
            expect(territory.quota).to be_nil
          end
        end
      end

      context 'has_many' do
        context 'when nested select statement' do
          it 'formulates the correct SOQL query' do
            soql = Account.select(opportunities: :id).includes(:opportunities).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, OwnerId, (SELECT Id FROM Opportunities) FROM Account WHERE (Id = '123')"
          end
        end

        context 'with standard objects' do
          it 'formulates the correct SOQL query' do
            soql = Account.includes(:opportunities).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, OwnerId, (SELECT Id, AccountId FROM Opportunities) FROM Account WHERE (Id = '123')"
          end

          it 'builds the associated objects and caches them' do
            response = [build_restforce_sobject({
              'Id' => '123',
              'Opportunities' => build_restforce_collection([
                {'Id' => '213', 'AccountId' => '123'},
                {'Id' => '214', 'AccountId' => '123'}
              ])
            })]
            allow(client).to receive(:query).once.and_return response
            account = Account.includes(:opportunities).find '123'
            expect(account.opportunities).to be_an Array
            expect(account.opportunities.all? { |o| o.is_a? Opportunity }).to eq true
          end
        end

        context 'with custom objects' do
          it 'formulates the correct SOQL query' do
            soql = Quota.includes(:prez_clubs).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, Bar_Id__c, (SELECT Id, QuotaId FROM PrezClubs__r) FROM Quota__c WHERE (Bar_Id__c = '123')"
          end

          it 'builds the associated objects and caches them' do
            response = [build_restforce_sobject({
              'Id' => '123',
              'PrezClubs__r' => build_restforce_collection([
                {'Id' => '213', 'QuotaId' => '123'},
                {'Id' => '214', 'QuotaId' => '123'}
              ])
            })]
            allow(client).to receive(:query).once.and_return response
            account = Quota.includes(:prez_clubs).find '123'
            expect(account.prez_clubs).to be_an Array
            expect(account.prez_clubs.all? { |o| o.is_a? PrezClub }).to eq true
          end
        end

        context 'mixing standard and custom objects' do
          it 'formulates the correct SOQL query' do
            soql = Quota.includes(:territories, :prez_clubs).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, Bar_Id__c, (SELECT Id, Quota__c, Name FROM Territories), (SELECT Id, QuotaId FROM PrezClubs__r) FROM Quota__c WHERE (Bar_Id__c = '123')"
          end

          it 'builds the associated objects and caches them' do
            response = [build_restforce_sobject({
              'Id' => '123',
              'PrezClubs__r' => build_restforce_collection([
                {'Id' => '213', 'QuotaId' => '123'},
                {'Id' => '214', 'QuotaId' => '123'}
              ]),
              'Territories' => build_restforce_collection([
                {'Id' => '213', 'Quota__c' => '123'},
                {'Id' => '214', 'Quota__c' => '123'}
              ])
            })]
            allow(client).to receive(:query).once.and_return response
            account = Quota.includes(:territories, :prez_clubs).find '123'
            expect(account.prez_clubs).to be_an Array
            expect(account.prez_clubs.all? { |o| o.is_a? PrezClub }).to eq true
            expect(account.territories).to be_an Array
            expect(account.territories.all? { |o| o.is_a? Territory }).to eq true
          end
        end

        context 'when assocation has a scope' do
          it 'formulates the correct SOQL query with the scope applied' do
            soql = Post.includes(:impossible_comments).where(id: '1234').to_s
            expect(soql).to eq "SELECT Id, Title__c, BlogId, IsActive, (SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comments__r WHERE (1 = 0)) FROM Post__c WHERE (Id = '1234')"
          end
        end

        context 'with namespaced SObjects' do
          it 'formulates the correct SOQL query' do
            soql = Salesforce::Quota.includes(:prez_clubs).where(id: '123').to_s
            expect(soql).to eq "SELECT Id, (SELECT Id, QuotaId FROM PrezClubs__r) FROM Quota__c WHERE (Id = '123')"
          end

          it 'builds the associated objects and caches them' do
            response = [build_restforce_sobject({
              'Id' => '123',
              'PrezClubs__r' => build_restforce_collection([
                {'Id' => '213', 'QuotaId' => '123'},
                {'Id' => '214', 'QuotaId' => '123'}
              ])
            })]
            allow(client).to receive(:query).once.and_return response
            account = Salesforce::Quota.includes(:prez_clubs).find '123'
            expect(account.prez_clubs).to be_an Array
            expect(account.prez_clubs.all? { |o| o.is_a? Salesforce::PrezClub }).to eq true
          end
        end

        context 'when there are no associated records returned by the query' do
          it 'caches the response' do
            response = [build_restforce_sobject({
              'Id' => '123',
              'Opportunities' => nil
            })]
            allow(client).to receive(:query).once.and_return response
            account = Account.includes(:opportunities).find '123'
            expect(account.opportunities).to eq []
            expect(account.opportunities).to eq []
          end
        end
      end

      describe 'mixing belongs_to and has_many' do
        it 'formulates the correct SOQL query' do
          soql = Account.includes(:opportunities, :owner).where(id: '123').to_s
          expect(soql).to eq "SELECT Id, OwnerId, (SELECT Id, AccountId FROM Opportunities), OwnerId.Id FROM Account WHERE (Id = '123')"
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'Opportunities' => build_restforce_collection([
              {'Id' => '213', 'AccountId' => '123'},
              {'Id' => '214', 'AccountId' => '123'}
            ]),
            'OwnerId' => {
              'Id' => '321'
            }
          })]
          allow(client).to receive(:query).once.and_return response
          account = Account.includes(:opportunities, :owner).find '123'
          expect(account.opportunities).to be_an Array
          expect(account.opportunities.all? { |o| o.is_a? Opportunity }).to eq true
          expect(account.owner).to be_a Owner
          expect(account.owner.id).to eq '321'
        end
      end

      context 'has_one' do
        context 'when assocation has a scope' do
          it 'formulates the correct SOQL query with the scope applied' do
            soql = Post.includes(:last_comment).where(id: '1234').to_s
            expect(soql).to eq "SELECT Id, Title__c, BlogId, IsActive, (SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__r WHERE (NOT ((Body__c = NULL))) ORDER BY CreatedDate DESC) FROM Post__c WHERE (Id = '1234')"
          end
        end

        context 'when query returns nil for associated record' do
          let(:response) do
            [build_restforce_sobject({ 'Id' => '123', 'Membership__r' => nil })]
          end

          before do
            allow(client).to receive(:query).and_return(response)
          end

          it 'the association method returns nil without making another request' do
            member = ClubMember.includes(:membership).where(id: '123').first
            membership = member.membership
            expect(membership).to be_nil
            expect(client).to have_received(:query).once
          end
        end
      end

      context 'when query returns an associated record' do
        let(:response) do
          [
            build_restforce_sobject(
              {
                'Id' => '123',
                'Membership__r' => build_restforce_collection([build_restforce_sobject({ 'Id' => '33' })])
              }
            )
          ]
        end

        before do
          allow(client).to receive(:query).and_return(response)
        end

        it 'the association method returns the record without making another request' do
          member = ClubMember.includes(:membership).where(id: '123').first
          expect(member.membership.id).to eq('33')
          expect(client).to have_received(:query).once
        end
      end

      context 'when invalid associations are passed' do
        context 'when the association is not defined' do
          it 'raises an error' do
            expect { Quota.includes(:invalid).find('123') }.to raise_error(ActiveForce::Association::InvalidAssociationError, 'Association named invalid was not found on Quota')
          end
        end
        context 'when the association is scoped and accepts an argument' do
          it 'raises and error' do
            expect { Post.includes(:reply_comments).find('1234')}.to raise_error(ActiveForce::Association::InvalidEagerLoadAssociation)
          end
        end
      end
    end

    describe '.includes with nested associations' do

      context 'with custom objects' do
        it 'formulates the correct SOQL query' do
          soql = Quota.includes(prez_clubs: :club_members).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id, Bar_Id__c,
              (SELECT Id, QuotaId,
                (SELECT Id, Name, Email FROM ClubMembers__r)
              FROM PrezClubs__r)
            FROM Quota__c
            WHERE (Bar_Id__c = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'PrezClubs__r' => build_restforce_collection([
              {'Id' => '213', 'QuotaId' => '123', 'ClubMembers__r' => build_restforce_collection([
                {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                {'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com'}
              ])},
              {'Id' => '214', 'QuotaId' => '123', 'ClubMembers__r' => build_restforce_collection([
                {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                {'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com'}
              ])}
            ])
          })]
          allow(client).to receive(:query).once.and_return response
          account = Quota.includes(prez_clubs: :club_members).find '123'
          expect(account.prez_clubs).to be_an Array
          expect(account.prez_clubs.all? { |o| o.is_a? PrezClub }).to eq true
          expect(account.prez_clubs.first.club_members).to be_an Array
          expect(account.prez_clubs.first.club_members.all? { |o| o.is_a? ClubMember }).to eq true
          expect(account.prez_clubs.first.club_members.first.id).to eq '213'
          expect(account.prez_clubs.first.club_members.first.name).to eq 'abc'
          expect(account.prez_clubs.first.club_members.first.email).to eq 'abc@af.com'
        end
      end

      context 'when the associations have scopes' do
        it 'generates the correct SOQL query' do
          soql = Blog.includes(active_posts: :impossible_comments).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id, Name, Link__c,
              (SELECT Id, Title__c, BlogId, IsActive,
                (SELECT Id, PostId, PosterId__c, FancyPostId, Body__c
                  FROM Comments__r WHERE (1 = 0))
                FROM Posts__r
                WHERE (IsActive = true))
              FROM Blog__c
              WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'Posts__r' => build_restforce_collection([
                {'Id' => '213', 'IsActive' => true, 'Comments__r' => [{'Id' => '987'}]},
                {'Id' => '214', 'IsActive' => true, 'Comments__r' => [{'Id' => '456'}]}
              ])
          })]
          allow(client).to receive(:query).once.and_return response
          blog = Blog.includes(active_posts: :impossible_comments).find '123'
          expect(blog.active_posts).to be_an Array
          expect(blog.active_posts.all? { |o| o.is_a? Post }).to eq true
          expect(blog.active_posts.first.impossible_comments.first).to be_a Comment
          expect(blog.active_posts.first.impossible_comments.first.id).to eq '987'
        end
      end

      context 'with namespaced sobjects' do
        it 'formulates the correct SOQL query' do
          soql = Salesforce::Account.includes({opportunities: :owner}).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id, Business_Partner__c,
              (SELECT Id, OwnerId, AccountId, Business_Partner__c, Owner.Id
              FROM Opportunities)
            FROM Account
            WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'opportunities' => build_restforce_collection([
              {'Id' => '213', 'AccountId' => '123', 'OwnerId' => '321', 'Business_Partner__c' => '123', 'Owner' => {'Id' => '321'}},
              {'Id' => '214', 'AccountId' => '123', 'OwnerId' => '321', 'Business_Partner__c' => '123', 'Owner' => {'Id' => '321'}}            ])
          })]
          allow(client).to receive(:query).once.and_return response
          account = Salesforce::Account.includes({opportunities: :owner}).find '123'
          expect(account.opportunities).to be_an Array
          expect(account.opportunities.all? { |o| o.is_a? Salesforce::Opportunity }).to eq true
          expect(account.opportunities.first.owner).to be_a Salesforce::User
          expect(account.opportunities.first.owner.id).to eq '321'
        end
      end

      context 'an array association nested within a hash association' do
        it 'formulates the correct SOQL query' do
          soql = Club.includes(book_clubs: [:club_members, :books]).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id,
            (SELECT Id, Name, Location,
              (SELECT Id, Name, Email FROM ClubMembers__r),
              (SELECT Id, Title, Author FROM Books__r)
            FROM BookClubs__r)
            FROM Club__c
            WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'BookClubs__r' => build_restforce_collection([
              {
                'Id' => '213',
                'Name' => 'abc',
                'Location' => 'abc_location',
                'ClubMembers__r' => build_restforce_collection([{'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},{'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com'}]),
                'Books__r' => build_restforce_collection([{'Id' => '213', 'Title' => 'Foo', 'Author' => 'author1'},{'Id' => '214', 'Title' => 'Bar', 'Author' => 'author2'}]),
              },
              {
                'Id' => '214',
                'Name' => 'def',
                'Location' => 'def_location',
                'ClubMembers__r' => build_restforce_collection([{'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},{'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com'}]),
                'Books__r' => build_restforce_collection([{'Id' => '213', 'Title' => 'Foo', 'Author' => 'author1'},{'Id' => '214', 'Title' => 'Bar', 'Author' => 'author2'}]),
              }
            ])
          })]
          allow(client).to receive(:query).once.and_return response
          club = Club.includes(book_clubs: [:club_members, :books]).find(id: '123')
          expect(club.book_clubs).to be_an Array
          expect(club.book_clubs.all? { |o| o.is_a? BookClub }).to eq true
          expect(club.book_clubs.first.name).to eq 'abc'
          expect(club.book_clubs.first.location).to eq 'abc_location'
          expect(club.book_clubs.first.club_members).to be_an Array
          expect(club.book_clubs.first.club_members.all? { |o| o.is_a? ClubMember }).to eq true
          expect(club.book_clubs.first.club_members.first.id).to eq '213'
          expect(club.book_clubs.first.club_members.first.name).to eq 'abc'
          expect(club.book_clubs.first.club_members.first.email).to eq 'abc@af.com'
          expect(club.book_clubs.first.books).to be_an Array
          expect(club.book_clubs.first.books.all? { |o| o.is_a? Book }).to eq true
          expect(club.book_clubs.first.books.first.id).to eq '213'
          expect(club.book_clubs.first.books.first.title).to eq 'Foo'
          expect(club.book_clubs.first.books.first.author).to eq 'author1'
        end
      end

      context 'a hash association nested within a hash association' do
        it 'formulates the correct SOQL query' do
          soql = Club.includes(book_clubs: {club_members: :membership}).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id,
            (SELECT Id, Name, Location,
              (SELECT Id, Name, Email,
                (SELECT Id, Type, Club_Member_Id__c FROM Membership__r)
              FROM ClubMembers__r)
            FROM BookClubs__r)
            FROM Club__c
            WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'BookClubs__r' => build_restforce_collection([
              {
                'Id' => '213',
                'Name' => 'abc',
                'Location' => 'abc_location',
                'ClubMembers__r' => build_restforce_collection([
                  {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '111', 'Type' => 'Gold'}])},
                  {'Id' => '214', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '222', 'Type' => 'Silver'}])},
                ]),
              },
              {
                'Id' => '214',
                'Name' => 'def',
                'Location' => 'def_location',
                'ClubMembers__r' => build_restforce_collection([
                  {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '111', 'Type' => 'Gold'}])},
                  {'Id' => '214', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '222', 'Type' => 'Silver'}])},
                ]),
              }
            ])
          })]
          allow(client).to receive(:query).once.and_return response
          club = Club.includes(book_clubs: {club_members: :membership}).find(id: '123')
          expect(club.book_clubs).to be_an Array
          expect(club.book_clubs.all? { |o| o.is_a? BookClub }).to eq true
          expect(club.book_clubs.first.id).to eq '213'
          expect(club.book_clubs.first.name).to eq 'abc'
          expect(club.book_clubs.first.location).to eq 'abc_location'
          expect(club.book_clubs.first.club_members).to be_an Array
          expect(club.book_clubs.first.club_members.all? { |o| o.is_a? ClubMember }).to eq true
          expect(club.book_clubs.first.club_members.first.id).to eq '213'
          expect(club.book_clubs.first.club_members.first.name).to eq 'abc'
          expect(club.book_clubs.first.club_members.first.email).to eq 'abc@af.com'
          expect(club.book_clubs.first.club_members.first.membership).to be_a Membership
          expect(club.book_clubs.first.club_members.first.membership.id).to eq '111'
          expect(club.book_clubs.first.club_members.first.membership.type).to eq 'Gold'
        end
      end

      context 'mulitple nested associations' do
        it 'formulates the correct SOQL query' do
          soql = Club.includes({prez_clubs: {club_members: :membership}}, {book_clubs: [:club_members, :books]}).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id,
            (SELECT Id, QuotaId,
              (SELECT Id, Name, Email,
                (SELECT Id, Type, Club_Member_Id__c FROM Membership__r)
              FROM ClubMembers__r)
            FROM PrezClubs__r),
            (SELECT Id, Name, Location,
              (SELECT Id, Name, Email FROM ClubMembers__r),
              (SELECT Id, Title, Author FROM Books__r)
            FROM BookClubs__r)
            FROM Club__c
            WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'PrezClubs__r' => build_restforce_collection([
              {'Id' => '213', 'QuotaId' => '123', 'ClubMembers__r' => build_restforce_collection([
                {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '111', 'Type' => 'Gold'}])},
                {'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '222', 'Type' => 'Silver'}])},
              ])},
              {'Id' => '214', 'QuotaId' => '123', 'ClubMembers__r' => build_restforce_collection([
                {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '111', 'Type' => 'Gold'}])},
                {'Id' => '214', 'Name' => 'def', 'Email' => 'def@af.com', 'Membership__r' => build_restforce_collection([{'Id' => '222', 'Type' => 'Silver'}])},
              ])}
            ]),
            'BookClubs__r' => build_restforce_collection([
              {
                'Id' => '213',
                'Name' => 'abc',
                'Location' => 'abc_location',
                'ClubMembers__r' => build_restforce_collection([
                  {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                  {'Id' => '214', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                ]),
                'Books__r' => build_restforce_collection([
                  {'Id' => '213', 'Title' => 'Foo', 'Author' => 'author1'},
                  {'Id' => '214', 'Title' => 'Bar', 'Author' => 'author2'},
                ])
              },
              {
                'Id' => '214',
                'Name' => 'def',
                'Location' => 'def_location',
                'ClubMembers__r' => build_restforce_collection([
                  {'Id' => '213', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                  {'Id' => '214', 'Name' => 'abc', 'Email' => 'abc@af.com'},
                ]),
                'Books__r' => build_restforce_collection([
                  {'Id' => '213', 'Title' => 'Foo', 'Author' => 'author1'},
                  {'Id' => '214', 'Title' => 'Bar', 'Author' => 'author2'},
                ])
              }
            ])
          })]
          allow(client).to receive(:query).once.and_return response
          club = Club.includes({prez_clubs: {club_members: :membership}}, {book_clubs: [:club_members, :books]}).find(id: '123')
          expect(club.prez_clubs).to be_an Array
          expect(club.prez_clubs.all? { |o| o.is_a? PrezClub }).to eq true
          expect(club.prez_clubs.first.club_members).to be_an Array
          expect(club.prez_clubs.first.club_members.all? { |o| o.is_a? ClubMember }).to eq true
          expect(club.prez_clubs.first.club_members.first.id).to eq '213'
          expect(club.prez_clubs.first.club_members.first.name).to eq 'abc'
          expect(club.prez_clubs.first.club_members.first.email).to eq 'abc@af.com'
          expect(club.prez_clubs.first.club_members.first.membership).to be_a Membership
          expect(club.prez_clubs.first.club_members.first.membership.id).to eq '111'
          expect(club.prez_clubs.first.club_members.first.membership.type).to eq 'Gold'
          expect(club.book_clubs).to be_an Array
          expect(club.book_clubs.all? { |o| o.is_a? BookClub }).to eq true
          expect(club.book_clubs.first.id).to eq '213'
          expect(club.book_clubs.first.name).to eq 'abc'
          expect(club.book_clubs.first.location).to eq 'abc_location'
          expect(club.book_clubs.first.club_members).to be_an Array
          expect(club.book_clubs.first.club_members.all? { |o| o.is_a? ClubMember }).to eq true
          expect(club.book_clubs.first.club_members.first.id).to eq '213'
          expect(club.book_clubs.first.club_members.first.name).to eq 'abc'
          expect(club.book_clubs.first.club_members.first.email).to eq 'abc@af.com'
          expect(club.book_clubs.first.books).to be_an Array
          expect(club.book_clubs.first.books.all? { |o| o.is_a? Book }).to eq true
          expect(club.book_clubs.first.books.first.id).to eq '213'
          expect(club.book_clubs.first.books.first.title).to eq 'Foo'
          expect(club.book_clubs.first.books.first.author).to eq 'author1'
        end
      end

      context 'nested belongs-to association' do
        it 'formulates the correct SOQL query' do
          soql = Comment.includes(post: :blog).where(id: '123').to_s
          expect(soql).to eq <<-SOQL.squish
            SELECT Id, PostId, PosterId__c, FancyPostId, Body__c,
              PostId.Id, PostId.Title__c, PostId.BlogId, PostId.IsActive,
                PostId.BlogId.Id, PostId.BlogId.Name, PostId.BlogId.Link__c
            FROM Comment__c
            WHERE (Id = '123')
          SOQL
        end

        it 'builds the associated objects and caches them' do
          response = [build_restforce_sobject({
            'Id' => '123',
            'PostId' => '321',
            'PosterId__c' => '432',
            'FancyPostId' => '543',
            'Body__c' => 'body',
            'PostId' => {
              'Id' => '321',
              'Title__c' => 'title',
              'BlogId' => '432',
              'BlogId' => {
                'Id' => '432',
                'Name' => 'name',
                'Link__c' => 'link'
              }
            }
          })]
          allow(client).to receive(:query).once.and_return response
          comment = Comment.includes(post: :blog).find '123'
          expect(comment.post).to be_a Post
          expect(comment.post.id).to eq '321'
          expect(comment.post.title).to eq 'title'
          expect(comment.post.blog).to be_a Blog
          expect(comment.post.blog.id).to eq '432'
          expect(comment.post.blog.name).to eq 'name'
          expect(comment.post.blog.link).to eq 'link'
        end
      end

      context 'when invalid nested associations are passed' do
        it 'raises an error' do
          expect { Quota.includes(prez_clubs: :invalid).find('123') }.to raise_error(ActiveForce::Association::InvalidAssociationError, 'Association named invalid was not found on PrezClub')
        end
      end
    end
  end
end
