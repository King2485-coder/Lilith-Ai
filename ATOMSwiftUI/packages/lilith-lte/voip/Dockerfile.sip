FROM andrius/asterisk:latest

LABEL maintainer="Lilith Network"
LABEL description="Lilith Private LTE Voice Service"

# Install additional dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl \
    mpg123 \
    sox \
    && rm -rf /var/cache/apk/*

# Create necessary directories
RUN mkdir -p /var/log/lilith \
    /var/lib/asterisk/sounds/custom \
    /etc/asterisk/agi

# Copy Asterisk configurations
COPY asterisk/extensions.conf /etc/asterisk/
COPY asterisk/sip.conf /etc/asterisk/

# Copy Lilith voice prompts
COPY audio/*.mp3 /var/lib/asterisk/sounds/custom/

# Copy AGI scripts
COPY asterisk/agi/*.agi /etc/asterisk/agi/
RUN chmod +x /etc/asterisk/agi/*.agi

# Create sounds symlinks
RUN cd /var/lib/asterisk/sounds/custom && \
    ln -sf lilith_greeting.mp3 lilith_greeting && \
    ln -sf lilith_focus_prompt.mp3 lilith_focus_prompt && \
    ln -sf lilith_thankyou.mp3 lilith_thankyou && \
    ln -sf lilith_status.mp3 lilith_status && \
    ln -sf lilith_focus_red.mp3 lilith_focus_red && \
    ln -sf lilith_focus_blue.mp3 lilith_focus_blue && \
    ln -sf lilith_focus_green.mp3 lilith_focus_green && \
    ln -sf lilith_focus_amber.mp3 lilith_focus_amber && \
    ln -sf lilith_focus_unknown.mp3 lilith_focus_unknown

# Configure Asterisk
RUN echo '[options]' >> /etc/asterisk/asterisk.conf && \
    echo 'verbose = 3' >> /etc/asterisk/asterisk.conf && \
    echo 'debug = 0' >> /etc/asterisk/asterisk.conf

# Expose SIP ports
EXPOSE 5060/udp
EXPOSE 5060/tcp
EXPOSE 10000-10100/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD asterisk -rx "core show uptime" > /dev/null 2>&1 || exit 1

# Start Asterisk
CMD ["asterisk", "-f"]
