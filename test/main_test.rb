require 'git-api'
require 'test/unit'
require 'rack/test'
require 'fileutils'
require 'grit'
require 'json'

ENV['RACK_ENV'] = 'test'
GIT_PATH = "/tmp/testrepos"
GIT_REPO = "mytestrepo"

class GitApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    GitApi::App.set :git_path => GIT_PATH
    GitApi::App
  end
  
  def path 
    File.join(GIT_PATH, GIT_REPO+".git")
  end
  
  # Repo
  # ------------------------------------------------------------------
  
  def test_get_repo
    post '/repos', {:name => GIT_REPO}
    get "/repos/#{GIT_REPO}.git"
    assert_equal({ :path => path}.to_json, last_response.body)
    FileUtils.rm_rf path
  end
  
  def test_create_repo_without_extension
    post '/repos', {:name => GIT_REPO}
    assert last_response.ok?
    assert_equal({ :path => path}.to_json, last_response.body)
    FileUtils.rm_rf path
  end
  
  def test_create_repo_with_extension
    post '/repos', {:name => GIT_REPO+".git"}
    assert last_response.ok?
    assert_equal({ :path => path}.to_json, last_response.body)
    FileUtils.rm_rf path
  end
  
  # Branches
  # ------------------------------------------------------------------
  
  def test_list_branches
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    post "/repos/#{GIT_REPO}.git/branches/another/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My Second Commit"}
    get "/repos/#{GIT_REPO}.git/branches"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json.size, 2)
    assert last_response.body.include?("commit_sha")
    FileUtils.rm_rf path
  end
  
  def test_create_clean_branch
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "masterfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    post "/repos/#{GIT_REPO}.git/branches/slave/files", {:name => "slavefile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My Second Commit"}
    get "/repos/#{GIT_REPO}.git/branches/master/files"
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 1)
    assert_equal(json["files"][0], "masterfile.txt")
    get "/repos/#{GIT_REPO}.git/branches/slave/files"
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 1)
    assert_equal(json["files"][0], "slavefile.txt")
    FileUtils.rm_rf path
  end
  
  def test_create_filled_branch
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "masterfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    post "/repos/#{GIT_REPO}.git/branches/slave/files", {:name => "slavefile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My Second Commit", :from_branch => "master"}
    get "/repos/#{GIT_REPO}.git/branches/master/files"
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 1)
    assert_equal(json["files"][0], "masterfile.txt")
    get "/repos/#{GIT_REPO}.git/branches/slave/files"
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 2)
    FileUtils.rm_rf path
  end
  
  # Files
  # ------------------------------------------------------------------
  
  def test_create_file
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    blob = Grit::Repo.new(path).tree("master")/"myfile.txt"
    assert last_response.ok?
    assert_equal(blob.data, "Hello There")
    assert last_response.body.include?("commit_sha")
    FileUtils.rm_rf path
  end
  
  def test_update_file
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    blob = Grit::Repo.new(path).tree("master")/"myfile.txt"
    assert last_response.ok?
    assert_equal(blob.data, "Hello There")
    assert last_response.body.include?("commit_sha")
    FileUtils.rm_rf path
  end
  
  def test_read_file
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    get "/repos/#{GIT_REPO}.git/branches/master/files/myfile.txt"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["name"], "myfile.txt")
    assert_equal(json["contents"], "Hello There")
    FileUtils.rm_rf path
  end
  
  def test_read_file_in_folder
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "subfolder/myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    get "/repos/#{GIT_REPO}.git/branches/master/files/subfolder/myfile.txt"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["name"], "myfile.txt")
    assert_equal(json["contents"], "Hello There")
    FileUtils.rm_rf path
  end
  
  def test_read_files
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile2.txt", :contents => "Hello There Again", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My Second Commit"}
    get "/repos/#{GIT_REPO}.git/branches/master/files"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 2)
    assert_equal(json["files"][0], "myfile.txt")
    FileUtils.rm_rf path
  end
  
  def test_read_files_empty_branch
    post '/repos', {:name => GIT_REPO}
    get "/repos/#{GIT_REPO}.git/branches/master/files"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 0)
    FileUtils.rm_rf path
  end
  
  def test_read_files_in_folder
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "subfolder/myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "subfolder/myfile2.txt", :contents => "Hello There Again", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My Second Commit"}
    get "/repos/#{GIT_REPO}.git/branches/master/files/subfolder"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["files"].size, 2)
    assert_equal(json["files"][0], "myfile.txt")
    FileUtils.rm_rf path
  end
  
  # Test 404's
  # All routes use shared function, so they should all behave the same
  # ------------------------------------------------------------------
  
  def test_read_files_wrong_repo
    get "/repos/#{GIT_REPO}.git/branches/master/files/myfile.txt"
    assert_equal 404, last_response.status
    FileUtils.rm_rf path
  end
  
  def test_read_files_wrong_file
    post '/repos', {:name => GIT_REPO}
    get "/repos/#{GIT_REPO}.git/branches/master/files/myfile.txt"
    assert_equal 404, last_response.status
    FileUtils.rm_rf path
  end
  
  # Blobs
  # ------------------------------------------------------------------
  
  def test_get_blob
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    sha = Grit::Repo.new(path).commits.first.tree.blobs.first.id
    get "/repos/#{GIT_REPO}.git/blobs/#{sha}"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json["contents"], "Hello There")
    FileUtils.rm_rf path
  end
  
  # Refs
  # ------------------------------------------------------------------
  
  def test_get_refs
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    get "/repos/#{GIT_REPO}.git/refs"
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert_equal(json.size, 1)
    assert_equal(json[0]["ref"], "refs/heads/master")
    FileUtils.rm_rf path
  end
  
  def test_create_ref
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    sha = JSON.parse(last_response.body)["commit_sha"]
    post "/repos/#{GIT_REPO}.git/refs", {:ref => "rune", :sha => sha}
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert last_response.body.include?("sha")
    FileUtils.rm_rf path
  end
  
  # Tags
  # ------------------------------------------------------------------
  
  def test_create_tag
    post '/repos', {:name => GIT_REPO}
    post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
    sha = JSON.parse(last_response.body)["commit_sha"]
    post "/repos/#{GIT_REPO}.git/tags", {:tag => "version1", :message => "hello", :sha => sha, :type => "commit", :user => "Rune Madsen", :email => "rune@runemadsen.com"}
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert last_response.body.include?("sha")
    FileUtils.rm_rf path
  end
  
  # currently doesn't work as there is no way to create refs that are not refs/head in grit
  # def test_get_tags
  #     post '/repos', {:name => GIT_REPO}
  #     post "/repos/#{GIT_REPO}.git/branches/master/files", {:name => "myfile.txt", :contents => "Hello There", :encoding => "utf-8", :user => "Rune Madsen", :email => "rune@runemadsen.com", :message => "My First Commit"}
  #     sha = JSON.parse(last_response.body)["commit_sha"]
  #     post "/repos/#{GIT_REPO}.git/tags", {:tag => "version1", :message => "hello", :sha => sha, :type => "commit", :user => "Rune Madsen", :email => "rune@runemadsen.com"}
  #     get "/repos/#{GIT_REPO}.git/tags"
  #     FileUtils.rm_rf path
  #   end
  
end