require 'spec_helper'
require 'json'

describe Node2RPM do

  h = '{"versions":{"1.0.0":{"name":"test","version":"1.0.0","description":"test","repository":{"url":"git://github.com/test/test"},"homepage":"https://github.com/test/test","license":"MIT","licenses":[{"type":"GPL"}],"licenses_h":{"type":"BSD"}}}}'
  j = JSON.parse(h)

  define_method :test_case do |a: nil, b: nil, c: nil|
    k = j.dup
    r = k['versions']['1.0.0']
    r.delete(a) unless a.nil?
    r.delete(b) unless b.nil?
    r[b] = r[c] unless b.nil? || c.nil?
    t = Node2RPM::Attr.new('test', '1.0.0')
    t.instance_eval { @json = k ; @history = nil ; @version = nil ; @resp = r }
    t
  end

  it 'can get license key in string format' do
    expect(test_case.license).to eq('MIT')
  end

  it 'can handle licenses key in array format' do
    expect(test_case(a:'license').license).to eq('GPL')
  end

  it 'can handle licenses key in hash format' do
    expect(test_case(a:'license', b:'licenses', c:'licenses_h').license).to eq('BSD')
  end

  it 'can handle homepage key' do
    expect(test_case.homepage).to eq('https://github.com/test/test')
  end

  it 'can handle repository key' do
    expect(test_case(a:'homepage').homepage).to eq('https://github.com/test/test')
  end

  it 'can handle description key' do
    expect(test_case.description).to eq('test')
  end
end
