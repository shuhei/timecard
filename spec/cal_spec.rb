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
  let(:recurrence_str) { :missing_value }
  let(:start_date) { Time.new(2013, 9, 4, 9) }
  let(:end_date) { Time.new(2013, 9, 4, 12) }
  let(:summary) { 'Test Event' }
  let(:excluded_dates) { [] }
  subject { described_class.new(event_obj) }

  before do
    props = {
      summary: summary,
      recurrence: recurrence_str,
      start_date: start_date,
      end_date: end_date,
      excluded_dates: excluded_dates
    }
    allow(event_obj).to receive(:properties_).and_return(Container.new(props))
  end

  describe '#recurrent?' do
    context 'without recurrence' do
      let(:recurrence_str) { :missing_value }
      its(:recurrent?) { should be_false }
    end

    context 'with recurrence' do
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=1' }
      its(:recurrent?) { should be_true }
    end
  end

  describe '#parse_recurrence' do
    context 'without recurrence' do
      let(:recurrence_str) { :missing_value }
      its(:rec) { should be_nil }
    end

    context 'with recurrence' do
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TU,TH;WKST=MO;UNTIL=20130905T145959Z' }
      it 'parses recurrence string' do
        expect(subject.rec['FREQ']).to eq('WEEKLY')
        expect(subject.rec['WKST']).to eq('MO')
      end

      it 'converts interval to integer' do
        expect(subject.rec['INTERVAL']).to eq(2)
      end

      it 'converts byday to array' do
        expect(subject.rec['BYDAY']).to eq(['MO', 'TU', 'TH'])
      end

      it 'converts UNTIL to date' do
        expect(subject.rec['UNTIL']).to eq(Date.new(2013, 9, 5))
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

    context 'with daily event' do
      let(:recurrence_str) { 'FREQ=DAILY;INTERVAL=1;UNTIL=20130918T145959Z' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns true for the next day' do
        expect(subject.check_recurrent(date + 1.day)).to be_true
      end

      it 'returns true for day of UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks)).to be_true
      end

      it 'returns false for day after UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks + 1.day)).to be_false
      end
    end

    context 'with every-three-days event' do
      let(:recurrence_str) { 'FREQ=DAILY;INTERVAL=3;UNTIL=20130919T145959Z' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns false for the next day' do
        expect(subject.check_recurrent(date + 1.day)).to be_false
      end

      it 'returns true for 3 days later' do
        expect(subject.check_recurrent(date + 3.day)).to be_true
      end

      it 'returns true for day of UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks + 1.day)).to be_true
      end

      it 'returns false for day after UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks + 4.day)).to be_false
      end
    end

    context 'with weekly event' do
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=1;UNTIL=20130918T145959Z' }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns true for 1 week later' do
        expect(subject.check_recurrent(date + 1.week)).to be_true
      end

      it 'returns false for 1 week ago' do
        expect(subject.check_recurrent(date - 1.week)).to be_false
      end

      it 'returns true for day of UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks)).to be_true
      end

      it 'returns false for day after UNTIL' do
        expect(subject.check_recurrent(date + 3.weeks)).to be_false
      end
    end

    context 'with weekly event that ends at the midnight' do
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=1;UNTIL=20130918T145959Z' }
      let(:end_date) { Time.new(2013, 9, 5, 0, 0, 0) }

      it 'returns true for the starting date' do
        expect(subject.check_recurrent(date)).to be_true
      end

      it 'returns true for 1 week later' do
        expect(subject.check_recurrent(date + 1.week)).to be_true
      end

      it 'returns false for 1 week ago' do
        expect(subject.check_recurrent(date - 1.week)).to be_false
      end

      it 'returns true for day of UNTIL' do
        expect(subject.check_recurrent(date + 2.weeks)).to be_true
      end

      it 'returns false for day after UNTIL' do
        expect(subject.check_recurrent(date + 3.weeks)).to be_false
      end
    end

    context 'with weekly event with byday' do
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,SA' }

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
      let(:recurrence_str) { 'FREQ=WEEKLY;INTERVAL=2' }

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

  describe 'not supported events' do
    describe 'check overnight event' do
      context 'with another end_date' do
        let(:end_date) { start_date + 1.day }

        it 'raises an error' do
          expect { subject }.to raise_error
        end
      end

      context 'with midnight end_date' do
        let(:end_date) { (start_date + 1.day).beginning_of_day }

        it 'does not raise error' do
          expect { subject }.not_to raise_error
        end
      end
    end
  end
end
