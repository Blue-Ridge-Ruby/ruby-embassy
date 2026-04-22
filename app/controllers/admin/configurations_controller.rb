module Admin
  class ConfigurationsController < AdminController
    def index
      @configurations = Configuration.all_and_expected
    end

    def new
      @configuration = Configuration.new(name: params[:name])
    end

    def create
      @configuration = Configuration.new(configuration_params)

      if @configuration.save
        redirect_to admin_configurations_path, notice: "Configuration added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @configuration = Configuration.find(params[:id])
    end

    def update
      @configuration = Configuration.find(params[:id])

      if @configuration.update(configuration_params)
        redirect_to admin_configurations_path, notice: "Configuration updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      Configuration.find(params[:id]).destroy
      redirect_to admin_configurations_path, notice: "Configuration removed."
    end

    private

    def configuration_params
      params.require(:configuration).permit(:name, :value)
    end
  end
end
