# Base image for Ruby (you can specify a version)
FROM ruby:3.0.5

# Install any system dependencies (adjust based on your gem's needs)
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# Set the working directory inside the container
WORKDIR /app

# Expose a shell to allow interaction inside the container
CMD ["/bin/bash"]
