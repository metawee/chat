require 'rails_helper'

RSpec.describe Shawky::PhoneMask, :shawky do
  describe '.mask' do
    it 'keeps the last three digits by default' do
      expect(described_class.mask('+966542921507', 'last3')).to eq('•••••••••507')
    end

    it 'hides the number completely in hidden mode' do
      expect(described_class.mask('+966542921507', 'hidden')).to eq('••••••••')
    end

    it 'handles local and formatted numbers' do
      expect(described_class.mask('0101 223 9999', 'last3')).to eq('••••••••999')
      expect(described_class.mask('966542921507', 'last3')).to eq('•••••••••507')
    end

    it 'leaves values that are not phone numbers alone' do
      ['hello', '2026-10-30', '192.168.100.200', '12345', 'L-104582', nil, 42].each do |value|
        expect(described_class.mask(value, 'last3')).to eq(value)
      end
    end
  end

  describe '.mask_embedded' do
    it 'masks numbers inside longer text' do
      expect(described_class.mask_embedded('عميل +966 54 292 1507', 'last3')).to eq('عميل •••••••••507')
    end
  end
end
