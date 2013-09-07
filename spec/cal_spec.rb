$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'cal'

class Container
  def initialize(content)
    @content = content
  end

  def get
    @content
  end
end

describe Calendar do
end

describe Event do
  let(:event_obj) { double() }
  let(:reccurence_str) { :missing_value }
  let(:start_date) { Time.now }
  let(:end_date) { Time.now }
  subject { described_class.new(event_obj) }

  before do
    allow(event_obj).to receive(:recurrence).and_return(Container.new(reccurence_str))
    allow(event_obj).to receive(:start_date).and_return(Container.new(start_date))
    allow(event_obj).to receive(:end_date).and_return(Container.new(end_date))
  end

  describe '#recurrent?' do
    context 'without recurrence' do
      let(:reccurence_str) { :missing_value }
      its(:recurrent?) { should be_false }
    end

    context 'with recurrence' do
      let(:reccurence_str) { 'FREQ=WEEKLY;INTERVAL=1' }
      its(:recurrent?) { should be_true }
    end
  end

  describe '#parse_recurrence' do
    context 'without recurrence' do
      let(:reccurence_str) { :missing_value }
      its(:rec) { should be_nil }
    end

    context 'with recurrence' do
      let(:reccurence_str) { 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TU,TH;WKST=MO' }
      it 'parses recurrence string' do
        expect(subject.rec['FREQ']).to eq('WEEKLY')
        expect(subject.rec['WKST']).to eq('MO')
      end

      it 'converts interval to integer' do
        expect(subject.rec['INTERVAL']).to eq(2)
      end

      it 'converts interval to array' do
        expect(subject.rec['BYDAY']).to eq(['MO', 'TU', 'TH'])
      end
    end
  end

  describe '#method_missing' do
    it 'returns value of appscript object' do
      expect(subject.start_date).to eq(start_date)
      expect(subject.end_date).to eq(end_date)
    end
  end
end
