#!/usr/bin/env python2
# -*- coding: utf-8 -*-
#
# Copyright: © 2014 "nyov"
# License:   Expat
#
# This script will crawl a Redmine wiki website and write all the history
# of all pages found to a single branch inside a Git repository.
#
# The script will create a git repository in your working directory.
# It requires the scrapy (0.24) and pygit2 python packages.
# Aside from that it needs enough memory to hold all the records in
# memory until it can sort them by date and version and flush the
# git tree history in correct order to disk only at the very end.
#
# Created for importing from static html pages of a redmine wiki,
# (so some workarounds exist, for missing pages, in how the crawl runs)
# but should work on or easily be adaptable to the real thing.

import scrapy
from scrapy import log
from scrapy.contrib.linkextractors import LinkExtractor
from scrapy.http import Request, HtmlResponse
from scrapy.selector import Selector

import urlparse
import urllib
import re

import datetime
#from dateutil.parser import parse

# for git imports
import pygit2
import heapq
import calendar
import time

################
### SETTINGS ###
################

BOT_NAME = 'RedmineExporter'
BOT_VERSION = '1.0'
# how to identify to the target website
USER_AGENT = '%s/%s (+http://www.yourdomain.com)' % (BOT_NAME, BOT_VERSION)
# how many parallel connections to keep open to the target website
CONCURRENT_REQUESTS = 16

# show duplicate (dropped) requests
DUPEFILTER_DEBUG = False
# for debugging log level see end of file
################

def read_git_authors(file):
	"""Read a git (git-svn) authors.txt file

	which has the line format:
	handle = Full Name <and@some.email>
	"""
	authors = {}
	try:
		with open(file) as f:
			data = f.readlines()
			data = (l for l in data if not l.startswith('#'))
			for line in data: # if not line.startswith('#'):
				name, handle = line.strip().split(' = ')
				author, email = handle.rstrip('>').split(' <')
				authors[name] = (author, email)
				#print('\t%s => "%s" [%s]' % (name, author, email))
	except IOError: pass
	return authors


class RedmineUser(scrapy.Item):
	author = scrapy.Field()
	email = scrapy.Field()


class RedminePage(scrapy.Item):
	pagename = scrapy.Field()
	version = scrapy.Field()
	lastversion = scrapy.Field()
	updated = scrapy.Field()
	user = scrapy.Field()
	comment = scrapy.Field()
	content = scrapy.Field()
	# debug
	url = scrapy.Field()


class RedmineExportSpider(scrapy.Spider):
	"""Xonotic Redmine exporter"""

	name = BOT_NAME
	allowed_domains = ['dev.xonotic.org']
	start_urls = (
		# wiki's 'Index by title' page
		'http://dev.xonotic.org/projects/xonotic/wiki/index.html',
		# this page does not appear in the overview, wtf! I don't even...
		# oh, it's been renamed
		'http://dev.xonotic.org/projects/xonotic/wiki/IRC.html',
	)

	def start_requests(self):
		for link in self.start_urls[:1]: # index
			yield Request(url=link, callback=self.parse_index)
		for link in self.start_urls[1:]: # any other links
			yield Request(url=link, callback=self.parse_pages)

	def parse_index(self, response):
		l = LinkExtractor(allow=(r'/wiki/.*\.html'), restrict_xpaths=('//div[@id="wrapper"]//div[@id="content"]'))
		for link in l.extract_links(response):
			yield Request(link.url, callback=self.parse_pages)

	def parse_pages(self, response):
		url, = response.xpath('//div[@id="wrapper"]//div[@id="content"]//a[contains(@class, "icon-history")]/@href').extract()[:1] or [None]
		return Request(urlparse.urljoin(response.url, url), callback=self.parse_history_entry)

	def parse_history_entry(self, response):
		page = response.xpath('//div[@id="wrapper"]//div[@id="content"]')
		paginated, = page.xpath('.//span[@class="pagination"]/a[contains(text(), "Next")]/@href').extract()[:1] or [None]
		if paginated:
			# re-entry, missing pages workaround
			full, = page.xpath('.//span[@class="pagination"]/a[last()]/@href').extract()
			return Request(urlparse.urljoin(response.url, full), callback=self.parse_history)
			# missing recursion for more pages (200+ revisions)
		else:
			return self.parse_history(response)

	def parse_history(self, response):
		page = response.xpath('//div[@id="wrapper"]//div[@id="content"]')
		history = page.xpath('.//form//table/tbody/tr')
		pagename = re.match(r'.*/wiki/(.*)/history', response.url).group(1)
		lastversion = page.xpath('.//form//table/tbody/tr[1]/td[1]/a/text()').extract()[0]
		for row in history:
			i = RedminePage()
			i['pagename'] = pagename
			i['version'], = row.xpath('td[@class="id"]/a/text()').extract()[:1] or [None]
			i['version'] = int(i['version'])
			i['lastversion'] = int(lastversion)
			date, = row.xpath('td[@class="updated_on"]/text()').extract()
			# date parse, assume UTC
			#i['updated'] = parse(date)
			i['updated'] = datetime.datetime.strptime(date, "%m/%d/%Y %I:%M %p")
			i['user'], = row.xpath('td[@class="author"]/a[contains(@class, "user")]/text()').extract()[:1] or [None]
			userpage, = row.xpath('td[@class="author"]/a[contains(@class, "user")]/@href').extract()[:1] or [None]
			if userpage is not None:
				yield Request(urlparse.urljoin(response.url, userpage), callback=self.parse_user)
			i['comment'], = row.xpath('td[@class="comments"]/text()').extract()[:1] or [None]
			content, = row.xpath('td[@class="buttons"]//a[contains(@href, "annotate.html")]/@href').extract()[:1] or [None]
			request = Request(urlparse.urljoin(response.url, content), callback=self.parse_page)
			request.meta['item'] = i
			yield request

	def parse_user(self, response):
		i = RedmineUser()
		user = response.xpath('//div[@id="wrapper"]//div[@id="content"]')
		i['author'], = user.xpath('h2/text()').extract()[:1] or [None]
		i['author'] = i['author'].strip()
		#i['email'], = user.xpath('div[@class="splitcontentleft"]/ul[1]/li/a[contains(@href, "mailto")]/text()').extract()[:1] or [None]
		i['email'], = user.xpath('div[@class="splitcontentleft"]/ul[1]/li/script/text()').re(r'.*\'(.*)\'')[:1] or [None]
		if not i['email']:
			i['email'] = '%s@' % i['author']
		else:
			email = urllib.unquote(i['email']).lstrip('document.write(\'').rstrip('\');').decode('string_escape').replace('\\/', '/')
			fake = Selector(HtmlResponse(response.url, encoding='utf-8', body=email))
			i['email'], = fake.xpath('//a/text()').extract()[:1] or [None]
		return i

	def parse_page(self, response):
		i = response.meta['item']
		page = response.xpath('//div[@id="wrapper"]//div[@id="content"]')
		lines = page.xpath('table[contains(@class, "filecontent")]//tr/td[@class="line-code"]') # keep empty lines!
		i['url'] = response.url
		i['content'] = ''
		for line in lines:
			line = (line.xpath('pre/text()').extract() or [u''])[0]
			i['content'] += line + '\n'

		return i



class GitImportPipeline(object):
	"""Git dumper"""

	def __init__(self, *a, **kw):
		self.repo = pygit2.init_repository('wiki.git', False) # non-bare repo
		self.heap = [] # heap for sorting commits
		self.committer = pygit2.Signature('RedmineExport', 'redmineexport@dev.xonotic.org', encoding='utf-8')
		self.users = {}

	def open_spider(self, spider):
		self.users = read_git_authors("redmine-authors.txt")

	def close_spider(self, spider):
		self.write_git(spider)

	def process_item(self, i, spider):
		if isinstance(i, RedmineUser):
			# prefer pre-loaded identities from local file
			if i['author'] not in self.users:
				self.users[i['author']] = (i['author'], i['email'])
			log.msg("Scraped user %s" % (i['author'],), spider=spider, level=log.INFO)

		if isinstance(i, RedminePage):
			oid = self.repo.create_blob(i['content'].encode("utf8"))
			ts = calendar.timegm(i['updated'].utctimetuple()) # datetime to unix timestamp for sorting
			heapq.heappush(self.heap, (ts, i['version'], oid, i))
			log.msg('Scraped page "%s" @ %s' % (i['pagename'], i['version']), spider=spider, level=log.INFO)

		return i

	def write_git(self, spider):
		parent = parent_id = None
		for _ in range(len(self.heap)):
			(ts, vsn, oid, i) = heapq.heappop(self.heap)

			commit_comment = i['comment'] or u''
			add_comment = u'\n\n(Commit created by redmine exporter script from page "%s" version %s)' % (i['pagename'], i['version'])

			if parent:
				tb = self.repo.TreeBuilder(parent.tree) # treeish ~= filesystem folder
			else:
				tb = self.repo.TreeBuilder()

			filename = '%s%s' % (i['pagename'], '.textile')

			tb.insert(filename, oid, pygit2.GIT_FILEMODE_BLOB)
			tree = tb.write() # create updated treeish with current page blob added

			parents = []
			if parent is not None:
				parents = [parent_id]

			(user, email) = self.users[i['user']]
			author = pygit2.Signature(user, email, time=ts, offset=0, encoding='utf-8')

			log.msg("Committing %s @ %s (%s)" % (i['pagename'], i['version'], oid), spider=spider, level=log.INFO)
			cid = self.repo.create_commit(
				'refs/heads/master',
				author, self.committer, commit_comment + add_comment, tree, parents, 'utf-8'
			)
			# commit is new parent for next commit
			parent = self.repo.get(cid)
			parent_id = cid


ITEM_PIPELINES = { # HAXX :D
	GitImportPipeline: 800,
}

# haxx: sad monkeypatch, might break
from importlib import import_module
def load_object(path):
	try:
		dot = path.rindex('.')
	except ValueError:
		raise ValueError("Error loading object '%s': not a full path" % path)
	except AttributeError:
		return path # hax

	module, name = path[:dot], path[dot+1:]
	mod = import_module(module)

	try:
		obj = getattr(mod, name)
	except AttributeError:
		raise NameError("Module '%s' doesn't define any object named '%s'" % (module, name))

	return obj

scrapy.utils.misc.load_object = load_object
# end haxx

from scrapy.exceptions import DontCloseSpider
def finished_run():
	log.msg("""
┌───────────────────────────────────────┐
│           finished run                │
│                                       │
│ VERIFY IT REALLY FOUND ALL YOUR PAGES │
│      OR YOU WILL BE SORRY LATER       │
│                                       │
│ if it was successful, you now want to │
│ repack the dumped git object database:│
│                                       │
│ $ git reflog expire --expire=now --all│
│ $ git gc --prune=now                  │
│ $ git repack -A -d                    │
│ $ git gc --aggressive --prune=now     │
└───────────────────────────────────────┘
	""", spider=spider, level=log.INFO)


if __name__ == "__main__":
	# for scrapy 0.24
	from twisted.internet import reactor
	from scrapy.utils.project import get_project_settings
	from scrapy.crawler import Crawler
	from scrapy import log, signals

	import sys

	print("""
	┌───────────────────────────────────────┐
	│        Redmine Exporter script        │
	├───────────────────────────────────────┤
	│  handle with care,                    │
	│        don't kill your webserver,     │
	│                             ...enjoy  │
	└───────────────────────────────────────┘
	""")
	raw_input("Hit Enter to continue...")

	spider = RedmineExportSpider()
	settings = get_project_settings()
	settings.set('BOT_NAME', BOT_NAME, priority='cmdline')
	settings.set('USER_AGENT', USER_AGENT, priority='cmdline')
	settings.set('ITEM_PIPELINES', ITEM_PIPELINES, priority='cmdline')
	settings.set('CONCURRENT_REQUESTS', CONCURRENT_REQUESTS, priority='cmdline')
	settings.set('DUPEFILTER_DEBUG', DUPEFILTER_DEBUG, priority='cmdline')
	crawler = Crawler(settings)
	crawler.signals.connect(reactor.stop, signal=signals.spider_closed)
	crawler.signals.connect(finished_run, signal=signals.spider_closed)
	crawler.configure()
	crawler.crawl(spider)
	crawler.start()
#	log.start(loglevel=log.DEBUG)
	log.start(loglevel=log.INFO)
	log.msg("Starting run ...", spider=spider, level=log.INFO)
	reactor.run()
