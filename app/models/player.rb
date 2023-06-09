# == Schema Information
#
# Table name: players
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Player < ApplicationRecord
  # https://stackoverflow.com/questions/2057210/ruby-on-rails-reference-the-same-model-twice
  has_many :matches_won, class_name: "Match", foreign_key: "winner_id"
  has_many :matches_lost, class_name: "Match", foreign_key: "loser_id"
  # can't work out how to player.leagues
  # has_many :leagues, through: :matches_lost
  has_many :leagues_with_win, through: :matches_won, source: :league
  has_many :leagues_with_loss, through: :matches_lost, source: :league
  validates :name, presence: true, length: {maximum: 20}, uniqueness: {case_sensitive: false}
  default_scope -> { order(:priority, :name) }

  def matches
    (matches_won + matches_lost).sort_by { |m| m.date }.reverse
  end

  def leagues
    (leagues_with_win + leagues_with_loss).uniq
  end

  def matches_won_in(league)
    matches_won.where(league_id: league.id)
  end
  
  def matches_lost_in(league)
    matches_lost.where(league_id: league.id)
  end
  
  def matches_in(league)
    matches_won_in(league) + matches_lost_in(league)
  end

  def result(league, date)
    winning_matches = Match.before(date).where(winner_id: id).where(league_id: league.id)
    losing_matches = Match.before(date).where(loser_id: id).where(league_id: league.id)
    winning_match_scores = winning_matches&.sum(:score)
    losing_match_scores = league.loser_scores_zero? ? 0 : losing_matches&.sum(:score)
    score = (winning_match_scores || 0) - (losing_match_scores || 0)
    denominator = winning_matches.size + losing_matches.size
    average_score = denominator.nonzero? ? score / denominator : 0
    {score: score.round(0), average_score: average_score.round(1)}
  end

  def progress(league)
    hash = Hash.new
    # match_days = matches_in(league).map(&:date).uniq.sort
    league_matches = matches_in(league).sort_by { |m| m.created_at }
    # match_days.each { |d| hash[d.to_s] = result(league, d)[:score] }
    league_matches.each_with_index { |m, index| hash[index] = result(league, m.created_at)[:score] }
    hash
  end
end
