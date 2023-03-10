require 'spec_helper'

describe ActiveForce::SObject do
  let :post do
    Post.new(id: "1", title: 'Ham')
  end

  let :comment do
    Comment.new(id: "1", post_id: "1")
  end

  let :has_one_parent do
    HasOneParent.new(id: '1', comment: "BAR")
  end

  let :has_one_child do
    HasOneChild.new(id: '1', has_one_parent_id: '1')
  end

  let :client do
    double("sfdc_client", query: [Restforce::Mash.new("Id" => 1)])
  end

  before do
    ActiveForce.sfdc_client = client
  end

  describe "has_many_query" do
    it "should respond to relation method" do
      expect(post).to respond_to(:comments)
    end

    it "should return a ActiveQuery object" do
      expect(post.comments).to be_a ActiveForce::ActiveQuery
    end

    it 'makes only one API call to fetch the associated object' do
      expect(client).to receive(:query).once
      post.comments.to_a
      post.comments.to_a
    end

    describe 'to_s' do
      it "should return a SOQL statment" do
        soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (PostId = '1')"
        expect(post.comments.to_s).to eq soql
      end
    end

    context 'when the SObject is namespaced' do
      let(:account){ Foo::Account.new(id: '1') }

      it 'correctly infers the foreign key and forms the correct query' do
        soql = "SELECT Id, AccountId, Partner_Account_Id__c FROM Opportunity WHERE (AccountId = '1')"
        expect(account.opportunities.to_s).to eq soql
      end

      it 'uses an explicit foreign key if it is supplied' do
        soql = "SELECT Id, AccountId, Partner_Account_Id__c FROM Opportunity WHERE (Partner_Account_Id__c = '1')"
        expect(account.partner_opportunities.to_s).to eq soql
      end
    end
  end

  describe 'has_many(options)' do
    it 'should allow to send a different query table name' do
      soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (PostId = '1')"
      expect(post.ugly_comments.to_s).to eq soql
    end

    it 'should allow to change the foreign key' do
      soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (PosterId__c = '1')"
      expect(post.poster_comments.to_s).to eq soql
    end

    it 'should allow to add a where condition' do
      soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (1 = 0) AND (PostId = '1')"
      expect(post.impossible_comments.to_s).to eq soql
    end

    it 'accepts custom scoping' do
      soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (Body__c = 'RE: Ham') AND (PostId = '1') ORDER BY CreationDate DESC"
      expect(post.reply_comments.to_s).to eq soql
    end

    it 'accepts custom scoping that preloads associations of the association' do
      account = Salesforce::Account.new id: '1', business_partner: 'qwerty'
      soql = "SELECT Id, OwnerId, AccountId, Business_Partner__c, Owner.Id FROM Opportunity WHERE (Business_Partner__c = 'qwerty') AND (AccountId = '1')"
      expect(account.partner_opportunities.to_s).to eq soql
    end

    it 'should use a convention name for the foreign key' do
      soql = "SELECT Id, PostId, PosterId__c, FancyPostId, Body__c FROM Comment__c WHERE (PostId = '1')"
      expect(post.comments.to_s).to eq soql
    end
  end

  describe "has_one_query" do
    it "should respond to relation method" do
      expect(has_one_parent).to respond_to(:has_one_child)
    end

    it "should return a the correct child object" do
      expect(has_one_parent.has_one_child).to be_a HasOneChild
    end

    it "should allow to pass a foreign key as options" do
      HasOneParent.has_one :has_one_child, foreign_key: :fancy_parent_id
      allow(has_one_parent).to receive(:id).and_return "2"
      expect(client).to receive(:query).with("SELECT Id, has_one_parent_id__c, FancyParentId FROM HasOneChild__c WHERE (FancyParentId = '2') LIMIT 1")
      has_one_parent.has_one_child
      HasOneParent.has_one :has_one_child, foreign_key: :has_one_parent_id # reset association to original value
    end

    it 'makes only one API call to fetch the associated object' do
      expect(HasOneChild).to receive(:find_by).once.and_return(has_one_child)
      has_one_parent.has_one_child.id
      has_one_parent.has_one_child.id
    end

    describe "assignments" do
      let(:has_one) do
        has_one_parent = HasOneParent.new(id: '1')
        has_one_parent.has_one_child = HasOneChild.new(id: '1')
        has_one_parent
      end

      before do
        expect(client).to_not receive(:query)
      end

      it 'accepts assignment of an existing object as an association' do
        expect(client).to_not receive(:query)
        other_child = HasOneChild.new(id: "2")
        has_one.has_one_child = other_child
        expect(has_one.has_one_child.has_one_parent_id).to eq has_one.id
        expect(has_one.has_one_child).to eq other_child
      end

      it 'can desassociate an object by setting it as nil' do
        old_child = has_one.has_one_child
        has_one.has_one_child = nil
        expect(old_child.has_one_parent_id).to eq nil
        expect(has_one.has_one_child).to eq nil
      end
    end


    context 'when the SObject is namespaced' do
      let(:attachment){ Foo::Attachment.new(id: '1', lead_id: '2') }
      let(:lead){ Foo::Lead.new(id: '2') }

      it 'generates the correct query' do
        expect(client).to receive(:query).with("SELECT Id, Lead_Id__c, LeadId FROM Attachment WHERE (Lead_Id__c = '2') LIMIT 1")
        lead.attachment
      end

      it 'instantiates the correct object' do
        expect(lead.attachment).to be_instance_of(Foo::Attachment)
      end

      context 'when given a foreign key' do
        let(:lead) { Foo::Lead.new(id: '2') }

        it 'generates the correct query' do
          expect(client).to receive(:query).with("SELECT Id, Lead_Id__c, LeadId FROM Attachment WHERE (LeadId = '2') LIMIT 1")
          lead.fancy_attachment
        end
      end
    end
  end

  describe "belongs_to" do
    it "should get the resource it belongs to" do
      expect(comment.post).to be_instance_of(Post)
    end

    it "should allow to pass a foreign key as options" do
      Comment.belongs_to :post, foreign_key: :fancy_post_id
      allow(comment).to receive(:fancy_post_id).and_return "2"
      expect(client).to receive(:query).with("SELECT Id, Title__c FROM Post__c WHERE (Id = '2') LIMIT 1")
      comment.post
      Comment.belongs_to :post # reset association to original value
    end

    it 'makes only one API call to fetch the associated object' do
      expect(client).to receive(:query).once
      comment.post
      comment.post
    end

    describe "assignments" do
      let(:comment) do
        comment = Comment.new(id: '1')
        comment.post = Post.new(id: '1')
        comment
      end

      before do
        expect(client).to_not receive(:query)
      end

      it 'accepts assignment of an existing object as an association' do
        expect(client).to_not receive(:query)
        other_post = Post.new(id: "2")
        comment.post = other_post
        expect(comment.post_id).to eq other_post.id
        expect(comment.post).to eq other_post
      end

      it 'can desassociate an object by setting it as nil' do
        comment.post = nil
        expect(comment.post_id).to eq nil
        expect(comment.post).to eq nil
      end
    end

    context 'when the SObject is namespaced' do
      let(:attachment){ Foo::Attachment.new(id: '1', lead_id: '2') }

      it 'generates the correct query' do
        expect(client).to receive(:query).with("SELECT Id FROM Lead WHERE (Id = '2') LIMIT 1")
        attachment.lead
      end

      it 'instantiates the correct object' do
        expect(attachment.lead).to be_instance_of(Foo::Lead)
      end

      context 'when given a foreign key' do
        let(:attachment){ Foo::Attachment.new(id: '1', fancy_lead_id: '2') }

        it 'generates the correct query' do
          expect(client).to receive(:query).with("SELECT Id FROM Lead WHERE (Id = '2') LIMIT 1")
          attachment.fancy_lead
        end
      end
    end
  end
end
