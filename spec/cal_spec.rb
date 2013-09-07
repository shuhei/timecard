$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'cal'
require 'active_support/time'

class Container
  def initialize(content)
    @content = content
  end

  def get
    @content
  end
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

  describe '#check_recurrent' do
    let(:date) { Date.new(2013, 9, 4) } # Wed
    let(:start_date) { Time.new(2013, 9, 4, 9) }
    let(:end_date) { Time.new(2013, 9, 4, 12) }

    context 'with weekly event' do
      let(:reccurence_str) { 'FREQ=WEEKLY;INTERVAL=1' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns true for 1 week later' do
        expect(subject.check_recurrent(date + 1.week)).to be_true
      end

      it 'returns false for 1 week ago' do
        expect(subject.check_recurrent(date - 1.week)).to be_false
      end
    end

    context 'with weekly event with byday' do
      let(:reccurence_str) { 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,SA' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns false for day in the week and before the starting date' do
        expect(subject.check_recurrent(date - 2.days)).to be_false
      end

      it 'returns true for day in the week and after the starting date' do
        expect(subject.check_recurrent(date + 3.days)).to be_true
      end

      it 'returns false for another day in the week' do
        expect(subject.check_recurrent(date + 1.day)).to be_false
      end

      it 'returns true for days in the next week' do
        expect(subject.check_recurrent(date + 1.week - 2.days)).to be_true
        expect(subject.check_recurrent(date + 1.week)).to be_true
        expect(subject.check_recurrent(date + 1.week + 3.days)).to be_true
      end

      it 'returns false for 1 week ago' do
        expect(subject.check_recurrent(date - 1.week)).to be_false
      end
    end

    context 'with biweekly event' do
      let(:reccurence_str) { 'FREQ=WEEKLY;INTERVAL=2' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns false for 1 week later' do
        expect(subject.check_recurrent(date + 1.week)).to be_false
      end

      it 'returns true for 2 weeks later' do
        expect(subject.check_recurrent(date + 2.weeks)).to be_true
      end

      it 'returns false for 2 weeks ago' do
        expect(subject.check_recurrent(date - 2.weeks)).to be_false
      end
    end
  end
end
