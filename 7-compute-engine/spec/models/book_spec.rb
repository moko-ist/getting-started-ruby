# Copyright 2015, Google, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "spec_helper"
require "ostruct"

RSpec.describe Book do
  include ActiveJob::TestHelper

  def run_enqueued_jobs!
    enqueued_jobs.each {|job| run_enqueued_job! job }
  end

  def run_enqueued_job! job
    job_class = job[:job]

    job_arguments = job[:args].map do |arg|
      if arg.try :has_key?, "_aj_globalid" # ActiveJob object identifier
        GlobalID::Locator.locate arg["_aj_globalid"]
      else
        arg
      end
    end

    job_class.perform_now *job_arguments

    enqueued_jobs.delete job
  end

  it "requires a title" do
    allow_any_instance_of(Book).to receive(:lookup_book_details)

    expect(Book.new title: nil).not_to be_valid
    expect(Book.new title: "title").to be_valid
  end

  it "book details are automatically looked up when created" do
    expect(enqueued_jobs).to be_empty

    book = Book.create title: "A Tale of Two Cities"

    expect(book.title).to eq "A Tale of Two Cities" # test

    expect(enqueued_jobs.length).to eq 1

    job = enqueued_jobs.first

    expect(job[:job]).to eq LookupBookDetailsJob
    expect(job[:args]).to eq [{ "_aj_globalid" => book.to_global_id.to_s }]

    run_enqueued_jobs!

    expect(enqueued_jobs).to be_empty

    book = Book.find book.id
    expect(book.title).to eq "A Tale of Two Cities"
    expect(book.author).to eq "Charles Dickens"
    expect(book.description).to eq "\"It was the best of times, it was the "\
    "worst of times.\" Charles Dickens' classic novel tells the story of "\
    "two Englishmen--degenerate lawyer Sydney Carton and aristocrat Charles "\
    "Darnay--who fall in love with the same woman in the midst of the French "\
    "Revolution's blood and terror. Originally published as 31 weekly "\
    "instalments,A Tale of Two Cities has been adapted several times for "\
    "film, serves as a rite of passage for many students, and is one of the "\
    "most famous novels ever published. This is a free digital copy of a "\
    "book that has been carefully scanned by Google as part of a project to "\
    "make the world's books discoverable online. To make this print edition "\
    "available as an ebook, we have extracted the text using Optical "\
    "Character Recognition (OCR) technology and submitted it to a review "\
    "process to ensure its accuracy and legibility across different screen "\
    "sizes and devices. Google is proud to partner with libraries to make "\
    "this book available to readers everywhere."
    expect(book.image_url).to eq "http://books.google.com/books/content?id=5EIPAAAAQAAJ&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api"
  end

  it "book details are only looked up when fields are blank"

end
