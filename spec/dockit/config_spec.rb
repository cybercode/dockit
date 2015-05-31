require 'spec_helper'
require 'dockit/config' # for spectator

describe Dockit::Config do
  def file(name)
    File.join(File.dirname(__FILE__), "#{name}.yaml")
  end
  context 'Bad file' do
    subject do
      Dockit::Config.new(file)
    end
    it 'requires a config file' do
      expect {Dockit::Config.new}.to raise_error(ArgumentError)
    end
    it 'should be a valid yaml file' do
      expect { Dockit::Config.new(file('bad')) }.to raise_error(Psych::SyntaxError)
    end
    it 'the config file should exist' do
      expect {Dockit::Config.new('foo.yaml')}.to raise_error(Errno::ENOENT)
    end
  end
  context 'simple file' do
    subject do
      Dockit::Config.new(file('simple'))
    end

    it { is_expected.to be_a Dockit::Config }

    it 'gets a config section' do
      expect(subject.get('build')).to eq({'t' => 'simple'})
    end

    it 'is key type indifferent' do
      expect(subject.get(:build)).to eq({'t' => 'simple'})
    end

    it 'gets a config value' do
      expect(subject.get(:build, :t)).to eq('simple')
    end
  end

  context 'file with locals' do
    let(:path) {file('locals') }
    it 'should exit with a message if a local is missing' do
      expect { Dockit::Config.new(path) }.to raise_error(SystemExit, /forget/)
    end

    it 'should expand the locals' do
      expect(Dockit::Config.new(path, {name: 'test'}).get(:build, :t)).to eq('test')
    end
  end
end
