module ActiveRecord
  module ModelTranslations
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def translates(*attributes)
        attributes = attributes.map{ |attribute| attribute.to_sym }
        
        unless included_modules.include? InstanceMethods
          include InstanceMethods
          
          define_method :translated_attributes do
            @translated_attributes
          end
          
          define_method :cached_translations do
            type = self.class.to_s.downcase
            Rails.cache.fetch "#{type}_translations.#{id}" do
              statement = "SELECT * FROM #{type}_translations WHERE #{type}_id = #{id}"
              ActiveRecord::Base.connection.select_all(statement)
            end
          end

          after_save do |record|
            record.update_translations!
          end

          define_method :locales do
            return [] if new_record?
            cached_translations.map { |t| t[:locale].to_sym}.select{ |locale| I18n.locales.include?(locale) }
          end
        
        end
        
        attributes.each do |attribute|
          define_method "#{attribute}=".to_sym do |value|
            @translated_attributes ||= {}
            @translated_attributes[attribute] = value
          end

          define_method attribute do
            return nil if new_record?
            translation = Rails.cache.fetch "#{self.class.to_s.downcase}_translations.#{id}.#{attribute}.#{I18n.locale}" do                          
              cached_translations.detect { |t| t['locale'] == I18n.locale.to_s } ||
              cached_translations.detect { |t| t['locale'] == I18n.default_locale.to_s } ||
              cached_translations.detect { |t| t['locale'] == '' } || # not useful for everyone
              cached_translations.first
            end
            translation && translation[attribute.to_s]
          end
        end
          
      end
    end

    module InstanceMethods
      def update_translations!
        return if @translated_attributes.nil? || @translated_attributes.empty?
        type = self.class.to_s.downcase
        statement = "SELECT * FROM #{type}_translations WHERE #{type}_id = #{id} AND locale = '#{I18n.locale}'"
        translation = ActiveRecord::Base.connection.select_one(statement)
        if translation
          statement = "UPDATE #{type}_translations SET "
          statement << "updated_at = '#{DateTime.now.to_s(:db)}', "
          statement << @translated_attributes.map do |key, value|
            v = value ? value.gsub('"', '\"') : nil
            "#{key} = \"#{v}\""
          end.join(', ')
          statement << " WHERE id = #{translation['id']}"
        else
          keys = @translated_attributes.keys
          statement = "INSERT INTO #{type}_translations "
          statement << "(#{type}_id, locale, created_at, updated_at, " + keys.join(', ') + ") "
          statement << "VALUES (#{id}, '#{I18n.locale}', '#{DateTime.now.to_s(:db)}', '#{DateTime.now.to_s(:db)}', "
          statement << keys.map do |key|
            v = @translated_attributes[key] ? @translated_attributes[key].gsub('"', '\"') : nil
            "\"#{v}\""
          end.join(', ') + ")"
        end
        ActiveRecord::Base.connection.execute(statement)
        
        # clear related cached
        Rails.cache.delete "#{type}_translations.#{id}"
        @translated_attributes.each do |attribute|
          Rails.cache.delete "#{type}_translations.#{id}.#{attribute}.#{I18n.locale}"
        end
      end
    end
  end
end
