require 'spec_helper'
require 'bundler/audit/scanner'

describe Scanner do
  let(:bundle)    { 'unpatched_gems' }
  let(:directory) { File.join('spec','bundle',bundle) }

  subject { described_class.new(directory) }

  describe "#scan" do
    it "should yield results" do
      results = []

      subject.scan { |result| results << result }

      expect(results).not_to be_empty
    end

    context "when not called with a block" do
      it "should return an Enumerator" do
        expect(subject.scan).to be_kind_of(Enumerable)
      end
    end

    context "when auditing a bundle with unpatched gems" do
      let(:bundle) { 'unpatched_gems' }

      context "with defaults" do
        subject { super().scan.to_a }

        it "should match unpatched gems to their advisories" do
          expect(subject.all? { |result|
            result.advisory.vulnerable?(result.gem.version)
          }).to be_truthy
        end
      end

      context "when the :ignore option is given" do
        subject { super().scan(ignore: ['OSVDB-89025']) }

        it "should ignore the specified advisories" do
          ids = subject.map { |result| result.advisory.id }

          expect(ids).not_to include('OSVDB-89025')
        end
      end
    end

    context "when auditing a bundle with insecure sources" do
      let(:bundle) { 'insecure_sources' }

      subject { super().scan.to_a }

      it "should match unpatched gems to their advisories" do
        expect(subject[0].source).to eq('git://github.com/rails/jquery-rails.git')
        expect(subject[1].source).to eq('http://rubygems.org/')
      end
    end

    context "when auditing a secure bundle" do
      let(:bundle) { 'secure' }

      subject { super().scan.to_a }

      it "should print nothing when everything is fine" do
        expect(subject).to be_empty
      end
    end

    context "when the ignore option is configured in .bundler-audit.yml" do
      let(:bundle)    { 'unpatched_gems_with_dot_configuration' }
      let(:directory) { File.join('spec','bundle',bundle) }
      let(:scanner)  { described_class.new(directory) }

      subject { scanner.scan }

      it "should ignore the specified advisories" do
        ids = subject.map { |result| result.advisory.id }

        expect(ids).not_to include('OSVDB-89025')
      end

      context "when config path is absolute" do
        let(:bundle) { 'unpatched_gems' }
        let(:absolute_config_path) { File.absolute_path(File.join('spec','bundle','unpatched_gems_with_dot_configuration', '.bundler-audit.yml')) }
        let(:scanner) { described_class.new(directory,'Gemfile.lock',Database.new,absolute_config_path) }

        it "should read the config just fine" do
          ids = subject.map { |result| result.advisory.id }

          expect(ids).not_to include('OSVDB-89025')
        end
      end

      context "when config path is relative" do
        let(:bundle) { 'unpatched_gems' }
        let(:relative_config_path) { File.join('..', 'unpatched_gems_with_dot_configuration', '.bundler-audit.yml') }
        let(:scanner) { described_class.new(directory,'Gemfile.lock',Database.new,relative_config_path) }

        it "should read the config just fine" do
          ids = subject.map { |result| result.advisory.id }

          expect(ids).not_to include('OSVDB-89025')
        end
      end
    end
  end

  describe "#report" do
    let(:expected_results) { subject.scan.to_a }

    it "should return a Report object containing the results" do
      report = subject.report

      expect(report).to be_a(Bundler::Audit::Report)
      expect(report.results).to all(be_kind_of(Bundler::Audit::Results::Result))
    end

    it "should return a Report containing all identifiers seen during scanning" do
      report = subject.report
      expected_identifiers = %w[CVE-2013-0155 CVE-2013-0276 CVE-2013-1854 CVE-2013-1856 CVE-2014-3482 CVE-2015-3227 CVE-2015-7577 OSVDB-108664 OSVDB-89025 OSVDB-90072 OSVDB-91451 OSVDB-91453]

      expect(report.seen_identifiers).to contain_exactly(*expected_identifiers)
    end

    context "when some identifiers are ignored" do
      it "should return a Report containing the seen but ignored identifiers" do
        ignored_identifiers = %w[CVE-2013-0155 OSVDB-108664]
        report = subject.report(ignore: ignored_identifiers)

        expect(report.seen_identifiers).to include(*ignored_identifiers)
      end

      it "should return a Report listing the ignored identifiers" do
        ignored_identifiers = %w[CVE-2013-0155 OSVDB-108664]
        report = subject.report(ignore: ignored_identifiers)

        expect(report.ignored_identifiers).to contain_exactly(*ignored_identifiers)
      end
    end

    context "when given a block" do
      it "should yield results" do
        results = []

        subject.report { |result| results << result }

        expect(results).to_not be_empty
        expect(results).to all(be_kind_of(Bundler::Audit::Results::Result))
      end
    end
  end
end
