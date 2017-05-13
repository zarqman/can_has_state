module CanHasState
  module DirtyHelper
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Dirty
    end

    module ClassMethods

      def track_dirty(*attrs)
        define_attribute_methods attrs
        attrs.each do |attr|
          attr = attr.to_s
          attr_reader(attr) unless respond_to?(attr)
          has_writer = respond_to?("#{attr}=")
          define_method "#{attr}=" do |val|
            send("#{attr}_will_change!") unless val == send(attr)
            has_writer ? super(val) : instance_variable_set("@#{attr}", val)
            changed_attributes.delete(attr) if attribute_was(attr) == send(attr)
          end
        end
      end

    end

  end
end
