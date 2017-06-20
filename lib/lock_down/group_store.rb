module LockDown
  module GroupStore
    def self.all
      @groups ||= {}
    end

    def self.find(name)
      all[name]
    end

    def self.create(name, options = {})
      @groups ||= {}
      @groups[name] = Group.new(name, options)
    end

    def self.find_or_create(name, options = {})
      if all[name] && !options.empty?
        LockDown.logger.error(name) { "Group #{name} has already been configured elsewhere" }
        fail ConfigError, "Group #{name} has already been configured elsewhere - you may not override configurations"
      end

      all[name] || create(name, options)
    end

    def self.remove(group_name)
      return unless group = GroupStore.find(group_name)

      group.reset
      @groups.delete(group_name)
    end

    def self.remove_all
      all.keys.map { |x| GroupStore.remove(x) }
    end
  end
end
