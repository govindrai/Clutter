require 'bcrypt'
class User < ActiveRecord::Base
  include BCrypt
  has_many :tweets # works, doesn't include retweets
  has_many :followings # works
  has_many :followers # works and returns followers objects
  has_many :liked_tweets #works and returned liked tweet objects
  has_many :replied_tweets #works and returns replied tweet objects
  # has_many :retweets, through: :tweets, foreign_key: :retweet_id #NEED TO CREATE A NEW TABLE, THEN TACKLE TAGS.
  has_many :retweets

  validates :first_name, :last_name, :handle, :email, :password_hash, presence:true
  validates :handle, :email, uniqueness: true
  before_save :capitalize_names

  def authenticate(input_password)
    self.password == input_password
  end

  def password
    @password ||= Password.new(self.password_hash)
  end

  def password=(new_password)
   @password = Password.create(new_password)
   self.password_hash = @password
  end

  def full_name
    "#{self.first_name} #{self.last_name}"
  end

  def capitalize_names
    self.first_name = self.first_name.capitalize
    self.last_name = self.last_name.capitalize
  end

  def landing_page_feed
    # first thing we need is all the user's own tweets
    my_own_tweets = self.tweets
    followings = self.followings

    # then we want all his followers tweets
    my_followings_tweets = []
    followings.each do |following|
      my_followings_tweets << followings.tweets
    end

    # then we want all his follower tweets
    followings_retweets = []
    followings.each do |following|
      all_retweets_of_following = Retweet.find_by(user_id: following.id)
      all_retweets_of_following.each do |retweet|
        followings_retweets << retweet
      end
    end

    # then we want to remove all retweets where user is already following with the original tweet owner
    filtered_retweets = []
    followings_user_ids = followings.pluck(:user_id)
    followings_retweets.each do |followings_retweet|
      catch :following_user do
        original_tweet_owner_id = Tweet.find(followings_retweet.tweet_id).user.id
        followings_user_ids.each do |followings_user_id|
          if followings_user_id == original_tweet_owner_id
            throw :following_user
          else
            filtered_retweets << followings_retweet
          end
        end
      end
    end

    # for each tweet package them for view in format [tweet, x]
    retweet_package = []
    filtered_retweets.each do |retweet|
      Tweet.find(retweet.tweet_id)
    end
    # then we  get all his friends retweets where I do not follow the original_tweet's user. --> retweet objects
    # Clean retweet objects so original tweets are unique. In dispute take first created.
      # for each of those retweet objects create a array of two pairs ([tweet, retweet]) where the first is a retweet obj and the second is a original tweet
    #

    feed_user_ids = self.followings.pluck(:following_id) << self.id
    feed_user_ids_string = feed_user_ids.reduce('(') { |final_string, id| final_string + id.to_s + ',' }.chop + ')'
    all_tweets_ids = Tweet.where("user_id in #{feed_user_ids_string}").order(created_at: :desc).pluck(:tweet_id)
    all_retweets_ids = User.retweets.pluck(:tweet_id)
    all_tweets_ids - all_retweets_id
    # Tweet
  end

  def profile_page_feed
    self.tweets
  end

  def get_nested_objects(self_association_method, pluck_field_sym, class_name)
    nested_objects_ids = self_association_method.pluck(pluck_field_sym)
    nested_objects_ids_string = nested_objects_ids.reduce('(') { |final_string, id| final_string + id.to_s + ','}.chop + ')'
    class_name.where("id in #{nested_objects_ids_string}")
  end

  def get_followers
    get_nested_objects(self.followers, :follower_id, User)
  end

  def get_liked_tweets
    get_nested_objects(self.liked_tweets, :tweet_id, Tweet)
  end

  def get_replied_tweets
    get_nested_objects(self.replied_tweets, :tweet_id, Tweet)
  end

  def get_retweets
    get_nested_objects(self.retweets, :tweet_id, Tweet)
  end

  def get_tweet_count
    self.tweets.count
  end

  def get_followings_count
    self.followings.count
  end

  def get_followers_count
    self.followers.count
  end

  ## START -- FUNCTIONALITY FOR SUGGESTING USERS TO FOLLOW
  def get_following_ids_string
    following_ids = self.followings.pluck(:following_id) << self.id
    following_ids.reduce('(') { |final_string, id| final_string + id.to_s + ','}.chop + ')'
  end

  def get_not_following_users
    User.all.where("id not in #{self.get_following_ids_string}")
  end
  ## END -- FUNCTIONALITY FOR SUGGESTING USERS TO FOLLOW

end
