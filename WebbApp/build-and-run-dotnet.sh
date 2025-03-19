#!/bin/bash

# Compile SCSS to CSS
npm run build:sass

# Run dotnet build which will handle the bundling/minification
dotnet build