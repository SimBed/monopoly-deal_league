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
  has_many :matches_won, class_name: "Match", foreign_key: "winner_id", dependent: :destroy
  has_many :matches_lost, class_name: "Match", foreign_key: "loser_id", dependent: :destroy
  # can't work out how to player.leagues
  # has_many :leagues, through: :matches_lost
  has_many :leagues_with_win, through: :matches_won, source: :league
  has_many :leagues_with_loss, through: :matches_lost, source: :league
  validates :name, presence: true, length: {maximum: 20}, uniqueness: {case_sensitive: false}
  scope :order_by_priority_name, -> { order(priority: :desc, name: :asc) }

  def leagues
    leagues_with_win_ids = leagues_with_win.pluck(:id).join(',')
    leagues_with_loss_ids = leagues_with_loss.pluck(:id).join(',')
    league_ids = (leagues_with_win_ids + "," + leagues_with_loss_ids)
    League.select('*').from('leagues').where(id: league_ids.split(','))
  end

  def matches_won_in(league)
    league.is_a?(League) ? matches_won.where(league_id: league.id) : matches_won
  end
  
  def matches_lost_in(league)
    league.is_a?(League) ? matches_lost.where(league_id: league.id) : matches_lost
  end

  def matches_in(league)
    matches_won_ids = (league.is_a?(League) ? matches_won.where(league_id: league.id) : matches_won).pluck(:id).join(',')
    matches_lost_ids = (league.is_a?(League) ? matches_lost.where(league_id: league.id) : matches_lost).pluck(:id).join(',')
    matches_ids = (matches_won_ids + "," + matches_lost_ids)
    Match.select('*').from('matches').where(id: matches_ids.split(','))
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
    league_matches = matches_in(league).order(:date, :created_at)
    league_matches.each_with_index { |m, index| hash[index] = result(league, m.date)[:score] }
    hash
  end

  def extreme_score(league)
    { biggest_win: matches_won_in(league).maximum(:score) || 0, biggest_loss: matches_lost_in(league).maximum(:score) || 0 }
  end

  # TODO not correct for zero losses?
  def runs(league)
    scores = matches_in(league).order(:date, :created_at).pluck(:winner_id)
    {wins: scores.chunk_while { |i, j| (i == id) && (j == id) }.to_a.map { |run| run.length }.max,
    losses: scores.chunk_while { |i, j| (i != id) && (j != id) }.to_a.map { |run| run.length }.max}
  end
end
