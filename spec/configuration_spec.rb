# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::FingerprintFlow::Configuration do
  def configuration(priority = nil)
    values = {}
    values["priority"] = priority unless priority.nil?
    described_class.new(make_site(dest: "/site", config: { "fingerprint_flow" => values }))
  end

  it "defaults the post_write priority to 12" do
    expect(configuration.post_write_priority).to eq(12)
  end

  it "accepts per-site priorities between normal processing and compression" do
    expect(configuration(17).post_write_priority).to eq(17)
    expect(configuration(11).post_write_priority).to eq(11)
    expect(configuration(19).post_write_priority).to eq(19)
  end

  it "rejects priorities outside the reserved pipeline range" do
    [10, 20, "12", :normal].each do |priority|
      expect { configuration(priority) }.to raise_error(Jekyll::Errors::FatalException)
    end
  end
end
