def delete
    @course = Course.find(params[:id])
    @course.delete

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
end