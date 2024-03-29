class Admin::SettingsController < Admin::BaseController
  cache_sweeper :blog_sweeper

  def index
    if this_blog.base_url.blank?
      this_blog.base_url = blog_base_url
    end
    load_settings
  end

  def write; load_settings end
  def feedback; load_settings end
  def errors; load_settings; end
  
  def redirect
    flash[:notice] = _("Please review and save the settings before continuing")
    redirect_to :action => "index"
  end

  def update
    if request.post?
      Blog.transaction do
        params[:setting].each { |k,v| this_blog.send("#{k.to_s}=", v) }
        this_blog.save
        flash[:notice] = _('config updated.')
      end

      redirect_to :action => params[:from]
    end
  rescue ActiveRecord::RecordInvalid
    render params[:from]
  end

  def update_database
    @current_version = Migrator.current_schema_version
    @needed_version = Migrator.max_schema_version
    puts "Current: #{@current_version}"
    puts "Needed: #{@needed_version}"
    @support = Migrator.db_supports_migrations?
    @needed_migrations = Migrator.needed_migrations(@current_version).collect do |mig|
      mig.scan(/\d+\_([\w_]+)\.rb$/).flatten.first.humanize
    end
  end

  def migrate
    if request.post?
      Migrator.migrate
      redirect_to :action => 'update_database'
    end
  end
  
  def import_feed
    if this_blog.base_url.blank?
      this_blog.base_url = blog_base_url
    end
    load_settings
  end
  
  def import
    feed = Feedzirra::Feed.fetch_and_parse(params[:feed][:url])
    feed.entries.each do |item|
      a = Article.new
      a.author = 'admin'
      a.user = current_user
      a.title = item.title
      a.body = item.summary
      a.created_at = item.published
      a.published_at = item.published
      a.published = true
      a.allow_pings = true
      a.allow_comments = true     
      a.save
    end
    flash[:notice] = _("#{feed.entries.size} posts are imported successfully")
    redirect_to :controller => "content"
  end

  private
  def load_settings
    @setting = this_blog
  end
end
