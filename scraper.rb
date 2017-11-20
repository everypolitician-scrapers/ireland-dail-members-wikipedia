#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_rel 'lib'

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class MembersTable < Scraped::HTML
  decorator RemoveFootnotes
  decorator UnspanAllTables
  decorator WikidataIdsDecorator::Links

  field :members do
    member_rows.map { |tr| fragment(tr => MemberRow).to_h }
  end

  private

  def member_table
    noko.xpath('//h2[span[@id="TDs_by_party"]]//following-sibling::table[1]')
  end

  def member_rows
    member_table.xpath('./tr[td]')
  end

end

class MemberRow < Scraped::HTML

  field :name do
    name_field.text.tidy
  end

  field :id do
   name_field.css('a/@wikidata').map(&:text).first
  end

  field :constituency do
    constituency_field.text.tidy
  end

  field :constituency_wikidata do
    constituency_field.css('a/@wikidata').map(&:text).first
  end

  field :party do
    party_field.css('a').first.text
  end

  field :party_wikidata do
    party_field.css('a/@wikidata').map(&:text).first
  end

  private

  def td
    noko.css('td')
  end

  def name_field
    td[1]
  end

  def constituency_field
    td[2]
  end

  def party_field
    td[0]
  end
end

url = 'https://en.wikipedia.org/wiki/Members_of_the_32nd_D%C3%A1il'
data = scraper(url => MembersTable).members
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id], data)
