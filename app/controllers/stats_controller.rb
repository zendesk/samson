class StatsController < ApplicationController 

  def projects
    @stats = Project.find_by_sql('SELECT p.*, count(*) as c from projects p  
                                    JOIN jobs j ON j.project_id = p.id
                                    JOIN deploys d ON d.job_id = j.id 
                                    GROUP BY p.id
                                    ORDER BY c DESC;')

    respond_to do |format|
      format.json { render json: @stats }
    end   
  end 

end

