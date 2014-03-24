require 'protobuf_messages/messages'

module Spree
  class DevicesController < Spree::StoreController
    before_filter :correct_user, except: [:index, :activate, :start_activate]

    # GET /devices
    def index
      @devices = spree_current_user.devices
    end

    # GET /devices/1
    def show
      @devices = spree_current_user.devices
    end

    # GET /devices/1/edit
    def edit
    end

    # GET /devices/activate
    def start_activate
      render 'activate'
    end

    # POST /devices/activate
    def activate
      begin
        device = Activation.user_activates_device(spree_current_user, params[:activation_token])
      rescue Exception => e
        flash[:notice] = e.message
      else
        redirect_to device, notice: 'Device was successfully activated.'
      end
    end

    # PATCH/PUT /devices/1
    def update
      if @device.update(device_params)
        notify_device_with_new_settings
        redirect_to @device, notice: 'Device was successfully updated.'
      else
        render action: 'edit'
      end
    end

    # DELETE /devices/1
    def destroy
      @device.destroy
      redirect_to devices_url, notice: 'Device was successfully destroyed.'
    end

    private
      # Only allow a trusted parameter "white list" through.
      def device_params
        params.require(:device).permit(:name, outputs_attributes: [:id, :function, :compressor_delay, :sensor_id] )
      end

      def notify_device_with_new_settings
        connection = DeviceConnection.find_by_device_id( @device.hardware_identifier )

        # no need to send settings to a device that's not connected
        unless connection
          logger.warn "Device not connected during settings update #{@device.hardware_identifier}"
          logger.warn "Connected devices are: #{DeviceConnection.all.inspect}"
          return
        end

        data = {
          outputs: [],
          sensors: []
        }
        @device.outputs.each do |o|
          output = {
            index:            o.output_index,
            function:         Output::FUNCTIONS.values.index( o.function ),
            compressor_delay: o.compressor_delay,
            sensor_index:     o.sensor.sensor_index,
            output_mode:      o.output_mode
          }
          data[:outputs] << output
        end
        @device.sensors.each do |s|
          sensor = {
            index:            s.sensor_index,
            setpoint_type:    Sensor::SETPOINT_TYPE[s.setpoint_type],
            static_setpoint:  s.static_setpoint,
            temp_profile_id:  s.temp_profile_id
          }
          data[:sensors] << sensor
        end

        type = ProtobufMessages::ApiMessage::Type::DEVICE_SETTINGS_NOTIFICATION
        message = ProtobufMessages::Builder.build( type, data )
        logger.debug "Sending Device Settings Notification Message: #{message.inspect}"
        ProtobufMessages::Sender.send( message, connection )
      end

      def correct_user
        @device = spree_current_user.devices.find_by( id: params[:id] )
        redirect_to root_path, error: 'You can only see your own devices' unless @device
      end
  end
end
