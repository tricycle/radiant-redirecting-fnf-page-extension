module RedirectingFnfPageValidations
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def validates_parts_as_yaml_hash(*parts_to_validate)
      configuration = parts_to_validate.extract_options!

      validates_each(:parts, configuration) do |record, attr, page_parts|
        page_parts.select {|pp| parts_to_validate.include?(pp.name.to_sym) }.each do |page_part|
          error_message = <<-ERR
The #{page_part.name} page part doesn't appear to be formatted correctly. I can't offer much in the way of guidance, but the part should look something like:
<pre>
  old-page: /new-page
  old-directory/old-page: /new-directory/new-page
</pre>
          ERR
          begin
            hash_from_yaml = YAML.load(page_part.content)
            unless hash_from_yaml.is_a?(Hash)
              record.errors.add_to_base(error_message)
              page_part.errors.add :content, error_message
            end
            normalized_array_from_page_part # call this, to make sure it'll work in
                                            # #validates_parts_do_not_contain_duplicates
          rescue ArgumentError => e
            if e.message.match(/syntax/)
              record.errors.add_to_base(error_message)
              page_part.errors.add :content, error_message
            end
          end
        end
      end
    end
    def validates_parts_do_not_contain_duplicates(*parts_to_validate)
      configuration = parts_to_validate.extract_options!

      validates_each(:parts, configuration) do |record, attr, page_parts|
        hash = {}
        page_parts.select {|pp| parts_to_validate.include?(pp.name.to_sym) }.each do |page_part|
          page_part_arr =  normalized_array_from_page_part(page_part.content)
          page_part_arr.each do |key, val| 
            unless hash.has_key?(key)
              hash[key] = page_part.name
            else
              if hash[key] = page_part.name
                record.errors.add_to_base("You've defined what you want me to do with #{key} more than once in page part '#{page_part.name}'." ) 
              else
                record.errors.add_to_base("You've defined what you want me to do with #{key} in page part '#{page_part.name}' and in '#{hash[key]}'." ) 
              end
            end
          end
        end
      end
    end
    def validates_part_does_not_contain_duplicates(part_to_validate)
      validates_each(:parts, {}) do |record, attr, page_parts|
        page_part = page_parts.detect {|pp| pp.name.to_sym == part_to_validate }

        if page_part
          urls = page_part.content.split("\n").collect {|line| line.sub(%r[^/?],'/').sub(%r[/$],'') }
          dups = array_duplicates(urls)
          record.errors.add_to_base("You've included two versions of #{dups.to_sentence} in page part '#{page_part.name}'") unless dups.empty?
        end
      end
    end

    # FIXME: smelly code
    def normalized_array_from_page_part(str)
      main_arr = []
      str = str.gsub(/\r/, '')
      str_arr = str.split(/\n/)
      str_arr.each do |s|
        next if s.empty?
        node = s.split(': ')
        raise(ArgumentError, "Bad syntax.") unless (node.size == 2) && (node.first && node.last)
        sim_arr = [node[0].sub(%r[^/?],'/').sub(%r[/$],''), node[1].strip]
        main_arr << sim_arr
      end
      return main_arr
    end

    def array_duplicates(ary)
      h = Hash.new(0)
      ary.each {|e| h[e] += 1 }
      dups = []
      h.each do |k,v|
        dups << k if v > 1
      end
      dups
    end
  end

end
