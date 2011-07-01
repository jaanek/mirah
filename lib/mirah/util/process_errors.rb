# Copyright (c) 2010 The Mirah project authors. All Rights Reserved.
# All contributing project authors may be found in the NOTICE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mirah
  module Util
    module ProcessErrors
      begin
        java_import 'org.mirah.types.ErrorType'
      rescue NameError
        $CLASSPATH << File.dirname(__FILE__) + '/../../../javalib/typer.jar'
        java_import 'org.mirah.typer.ErrorType'
      end

      def process_errors(errors)
        errors.each do |ex|
          if ex.kind_of?(ErrorType)
            ex.message.each do |message, position|
              if position
                Mirah.print_error(message, position)
              else
                puts message
              end
            end if ex.message
          else
            puts ex
            if ex.respond_to?(:node) && ex.node
              Mirah.print_error(ex.message, ex.position)
            else
              puts ex.message
            end
            puts ex.backtrace if @verbose
          end
        end
        throw :exit unless errors.empty?
      end

      java_import 'mirah.lang.ast.NodeScanner'
      class ErrorCollector < NodeScanner
        def initialize
          @errors = {}
        end
        def enterDefault(node, arg)
          type = node.resolve
          @errors[type] ||= type if type.name == ':error'
          true
        end
        def errors
          @errors.values
        end
      end

      def process_inference_errors(nodes)
        errors = []
        nodes.each do |ast|
          collector = ErrorCollector.new
          ast.accept(collector, nil)
          errors.concat(collector.errors)
        end
        failed = !errors.empty?
        if failed
          puts "Inference Error:"
          process_errors(errors)
        end
      end
    end
  end
end