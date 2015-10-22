require 'spec_helper'

shared_examples 'a dockit config' do |meth, keys, dirs, ext|
  def dockit_files(names, ext)
    pwd = File.dirname(__FILE__)
    names.collect do |n|
      File.expand_path("deploy/#{n}/Dockit.#{ext}", pwd)
    end
  end

  let(:val) { subject.send(meth) }
  let(:files) { dockit_files(dirs, ext) }

  it "returns a hash" do
    expect(val).to_not be_empty
    expect(val).to be_a Hash
  end

  it 'is keyed by directory name' do
    expect(val.keys).to match_array(keys)
  end

  it "has a Dockit.#{ext} file for each key" do
    expect(val.values).to match_array(files)
  end
end

describe Dockit do
  it 'has a version number' do
    expect(Dockit::VERSION).to_not be_nil
  end

  it 'has an Env class' do
    expect(Dockit::Env).to be_a(Class)
  end

  it 'uses the current directory as the project root' do
    expect(Dockit::Env.new.root).to eq(Dir.pwd)
  end

  it 'has a Log class' do
    expect(Dockit::Log).to be_a(Class)
  end
end

describe Dockit::Log do
  it 'has a debug method' do
    expect(subject).to respond_to('debug')
  end

  describe '#debug' do
    it 'requires an array as its argument' do
      expect { subject.debug() }.to raise_error(ArgumentError)
      expect { subject.debug('foo') }.to raise_error(NoMethodError, /`join'/)
    end

    it 'prints the message to $stderr' do
      expect { subject.debug(%w[a test]) }.to output("DEBUG: a test\n").to_stderr
    end
  end
end

describe Dockit::Env do
  before do
    Dir.chdir(File.expand_path('deploy/mod', File.dirname(__FILE__)))
    @parent = File.expand_path('..')
  end

  it 'finds the project root' do
    expect(subject.root).to eq(@parent)
  end

  describe '#modules' do
    it_should_behave_like 'a dockit config', 'modules', %w[mod all], %w[. mod], 'rb'
  end

  describe '#services' do
    svcs = %w[mod svc]
    it_should_behave_like 'a dockit config', 'services', svcs, svcs, 'yaml'
  end
end

describe Dockit::Service do
  before do
    @env = Dockit::Env.new
  end

  subject do
    Dockit::Service.new(@env.services['mod'])
  end

  it 'should be created' do
    expect(subject).to be_a Dockit::Service
  end

  it "should get it's name from the build tag" do
    expect(subject.config.get(:build, :t)).to eq('mod:tagged')
    expect(subject.name).to eq('mod')
  end

  it "should get it's name from the create name" do
    expect(Dockit::Service.new(@env.services['svc']).name).to eq('a-test')
  end
end
