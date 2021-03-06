# ModelTranslations

Minimal implementation of Globalize2 style model translations. Rails 2.2 is
required.

## Installation

### Gem:

in config/environment.rb:

    config.gem 'model_translations'

### Plugin:

    script/plugin install git://github.com/guillaumegentil/model_translations.git

## Implementation

    class Post < ActiveRecord::Base
      translates :title, :text
    end

Allows you to translate values for the attributes :title and :text per locale:

    I18n.locale = :en
    post.title # ModelTranslations rocks!
    I18n.locale = :sv
    post.title # Rockar fett!

In order to make this work you need to take care of creating the appropriate
database migrations manually. The migration for the above Post model could look
like this:

    class CreatePosts < ActiveRecord::Migration
      def self.up
        create_table :posts do |t|
          t.timestamps
        end
        create_table :post_translations do |t|
          t.string     :locale
          t.references :post
          t.string     :title
          t.text       :text
          t.timestamps
        end
      end
      def self.down
        drop_table :posts
        drop_table :post_translations
      end
    end

To migrate from a model with existing attributes to one with translated
attributes the migration could look like this.

    class RemoveTitleTextFromPosts < ActiveRecord::Migration
      def self.up
        [:title, :text].each do |attribute|
          Post.all.each{|post| post.update_attribute(attribute, post.read_attribute(attribute)) }
          remove_column :post, attribute
        end
      end
      def self.down
        add_column :post, :title, :string
        add_column :post, :text, :text
        [:title, :text].each do |attribute|
          Post.all.each{|post| post.write_attribute(attribute, post.send(attribute)); post.save}
        end
      end
    end

## Advanced Querying

All models that have translations are hooked up with a has_many :translations 
association for their corresponding translation table. Use this to your advantage. 

Note that the following example requires Rails 2.3 since default_scope is used.

    class Post < ActiveRecord::Base
      translates :title, :text
    
      default_scope :include => :translations
    
      named_scope :translated, lambda { { :conditions => { 'post_translations.locale' => I18n.locale.to_s } } }
      named_scope :ordered_by_title, :order => 'post_translations.title'
      named_scope :with_title, lambda { |title| { :conditions => { 'post_translations.title' => title } } }
    end

    Post.translated.ordered_by_title # All posts with the current locale sorted on title
    Post.with_title('My translated title') # Equivalent to Post.find_all_by_title

As you can see including the model_translations on all querys by default gives 
us (apart from reducing the number of querys to the database) the possibility
of using the post_translations table for further query customization.


Copyright (c) 2008 Jan Andersson, released under the MIT license