# frozen_string_literal: true

# Structural contract check, not a behavioral one: a concrete adapter must
# not REQUIRE a keyword argument that the abstract base for its role leaves
# optional (the abstract bases all declare `**_options`/no required
# keywords), because CacheExecutor/JobExecutor/FlagExecutor call adapters
# through that abstract shape (e.g. `adapter.list_keys(**params.slice(:prefix,
# :limit))`), not through each concrete class's own signature. A concrete
# adapter that tightens a keyword from optional-in-the-abstract to
# required-in-the-concrete breaks at runtime with ArgumentError for any
# caller that omits it -- exactly finding f-l10-14 (RailsCacheAdapter#list_keys
# made `prefix:` required while CacheAdapter#list_keys is `**_options`).
RSpec.shared_examples "an admin tools adapter" do |abstract_class|
  it "requires no keyword beyond what #{abstract_class} requires, for every abstract method" do
    violations = abstract_class.instance_methods(false).filter_map do |method_name|
      next unless described_class.method_defined?(method_name)

      abstract_required = keyreq_names(abstract_class.instance_method(method_name))
      concrete_required = keyreq_names(described_class.instance_method(method_name))
      extra = concrete_required - abstract_required
      "##{method_name} requires #{extra.inspect} which #{abstract_class}##{method_name} does not" if extra.any?
    end

    expect(violations).to be_empty, violations.join("; ")
  end

  it "implements every method #{abstract_class} declares" do
    missing = abstract_class.instance_methods(false) - described_class.instance_methods(false)
    expect(missing).to be_empty, "#{described_class} is missing #{missing.inspect} from #{abstract_class}"
  end

  def keyreq_names(unbound_method)
    unbound_method.parameters.filter_map { |pair| pair[1] if pair[0] == :keyreq }
  end
end
