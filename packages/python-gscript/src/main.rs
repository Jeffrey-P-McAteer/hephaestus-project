
use python_parser::ast::*;
use web_view::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
  let file = std::env::args().into_iter().nth(1).unwrap_or("/tmp/my_script.py".to_string());

  let contents = std::fs::read_to_string(file.clone())?;

  match python_parser::file_input(python_parser::make_strspan(&contents)) {
    Err(e) => {
      eprintln!("e={}", e);
      return Err( Box::new(std::io::Error::new(std::io::ErrorKind::Other, "Cannot parse python code")) );
    }
    Ok(python_data) => {
      return show_python(file.clone(), python_data.1);
    }
  }

}


fn show_python(file: String, ast: Vec<Statement>) -> Result<(), Box<dyn std::error::Error>> {
  eprintln!("file={}", &file);
  eprintln!("ast={:#?}", ast);

  // Recursive GUI build using statements
  let gui_css = r#"<style>
p {
  margin: 0;
  padding: 0;
}
details {
  border: 1px solid black;
  background-color: #ffffff;
  padding: 0;
}
details > div.ast {
  padding: 1pt;
  padding-left: 24pt;
}
summary {
  background-color: #e0e0e0;
  margin: 0;
  padding: 0;
}

</style>"#;
  let gui_html = html_gui_build(&ast);

  web_view::builder()
        .title(&file)
        .content(Content::Html(format!("{}{}", gui_css, gui_html)))
        .size(600, 400)
        .resizable(true)
        .debug(false)
        .user_data(())
        .invoke_handler(|_webview, _arg| Ok(()))
        .run()?;


  Ok(())
}

fn html_gui_build(ast: &Vec<Statement>) -> String {
  let mut html = String::new();
  html.push_str("<div class='ast'>");
  for statement in ast {
    match statement {
      Statement::Import(import) => {
        match import {
          Import::Import{ names } => {
            let mut names_s = String::new();
            for (vec_name, opt_name) in names {
              names_s.push_str(&vec_name.join(" "));
            }

            html.push_str(
              format!("<p>import {}</p>", names_s).as_str()
            );
          }
          unk => {
            html.push_str(
              format!("<p>Unimplemented import for: {:?}</p>", unk).as_str()
            );
          }
        }
      }
      Statement::Compound(compound) => {
        match &**compound {
          CompoundStatement::If(vec_statement, opt_statement) => {
            let mut i = 0;
            for (cond_statement, body_statements) in vec_statement {
              let mut expr;
              if i < 1 {
                expr = "if";
              }
              else {
                expr = "elif";
              }
              
              html.push_str("<details class='ifstmt' open>");
              html.push_str(format!("<summary>{} {}:</summary>", expr, to_string(&cond_statement)).as_str());
              html.push_str(html_gui_build(&body_statements).as_str());
              html.push_str("</details>");

            }
            if let Some(else_body_statements) = opt_statement {
              html.push_str("<details class='ifstmt' open>");
              html.push_str("<summary>else:</summary>");
              html.push_str(html_gui_build(&else_body_statements).as_str());
              html.push_str("</details>");
            }

          }
          CompoundStatement::For{r#async, item, iterator, for_block, else_block} => {
            html.push_str("<p>For TODO</p>");
          }
          CompoundStatement::While(expression, statements, option_statements) => {
            html.push_str("<p>While TODO</p>");
          }
          CompoundStatement::Funcdef(funcdef) => {
            html.push_str("<details class='function' open>");
            html.push_str(format!("<summary>def {}({}) -> {:?}</summary>", funcdef.name, to_string_args(&funcdef.parameters), funcdef.return_type).as_str());
            html.push_str(html_gui_build(&funcdef.code).as_str());
            html.push_str("</details>");
          }
          unk => {
            html.push_str(
              format!("<p>Unimplemented compound for: {:?}</p>", unk).as_str()
            );
          }
        }
      }
      Statement::Assignment(lhs_expressions, rhs_expressions) => {
        let mut lhs_s = String::new();
        for lhs_expr in lhs_expressions {
          lhs_s.push_str(to_string(lhs_expr).as_str());
          lhs_s.push_str(", ");
        }

        let mut rhs_s = String::new();
        for expressions in rhs_expressions {
          for rhs_expr in expressions {
            rhs_s.push_str(to_string(rhs_expr).as_str());
            rhs_s.push_str(", ");
          }
        }

        html.push_str(
          format!("{} = {}", lhs_s, rhs_s).as_str()
        );
      }
      Statement::Pass => {
        html.push_str("<p>Pass</p>");
      }
      Statement::Return(vec_expression) => {
        html.push_str("<p>return ");
        for expr in vec_expression {
          html.push_str(
            format!("{}, ", to_string(expr)).as_str()
          );
        }
        html.push_str("</p>");
      }
      unk => {
        html.push_str(
          format!("<p>Unknown statement: {:?}</p>", unk).as_str()
        );
      }
    }
    html.push_str("<br>");
  }
  html.push_str("</div>");
  return html;
}

fn to_string(expr: &Expression) -> String {
  match expr {
    Expression::Name(name) => {
      name.to_string()
    }
    Expression::Int(int_type) => {
      int_type.to_string()
    }
    Expression::String(vec_pystring) => {
      let mut s = String::new();

      for pystring in vec_pystring {
        s.push_str(
          format!("{:?}", pystring.content).as_str()
        )
      }

      s
    }
    Expression::Bop(binary_op, lhs_expr, rhs_expr) => {
      format!("{}{}{}",
        to_string(lhs_expr),
        to_string_bop(binary_op),
        to_string(rhs_expr),
      )
    }
    unk => {
      format!("Unhandled: {:?}", unk)
    }
  }
}

fn to_string_args(args: &TypedArgsList) -> String {
  let mut s = String::new();
  for (name, _opt_expr, _opt_expr2) in &args.posonly_args {
    s.push_str(format!("{}, ", name).as_str());
  }
  for (name, _opt_expr, _opt_expr2) in &args.args {
    s.push_str(format!("{}, ", name).as_str());
  }
  match &args.star_args {
    StarParams::No => { }
    StarParams::Anonymous => {
      s.push_str("*, ");
    }
    StarParams::Named((name, _opt_expr)) => {
      s.push_str(format!("*{}, ", name).as_str());
    }
  }
  for (name, _opt_expr, _opt_expr2) in &args.keyword_args {
    s.push_str(format!("{}, ", name).as_str());
  }
  if let Some((name, _opt_expr)) = &args.star_kwargs {
    s.push_str(format!("**{}, ", name).as_str());
  }
  return s;
}

fn to_string_bop(bop: &Bop) -> String {
  match bop {
    Bop::Add => { "+".to_string() }
    Bop::Sub => { "-".to_string() }
    Bop::Mult => { "*".to_string() }
    Bop::Matmult => { "@".to_string() }
    Bop::Mod => { "%".to_string() }
    Bop::Floordiv => { "//".to_string() }
    Bop::Div => { "/".to_string() }
    Bop::Power => { "**".to_string() }
    Bop::Lshift => { "<<".to_string() }
    Bop::Rshift => { ">>".to_string() }
    Bop::BitAnd => { "&".to_string() }
    Bop::BitXor => { "^".to_string() }
    Bop::BitOr => { "|".to_string() }
    Bop::Lt => { "<".to_string() }
    Bop::Gt => { ">".to_string() }
    Bop::Eq => { "==".to_string() }
    Bop::Leq => { "<=".to_string() }
    Bop::Geq => { ">=".to_string() }
    Bop::Neq => { "!=".to_string() }
    Bop::In => { "in".to_string() }
    Bop::NotIn => { "not in".to_string() }
    Bop::Is => { "is".to_string() }
    Bop::IsNot => { "is not".to_string() }
    Bop::And => { "and".to_string() }
    Bop::Or => { "or".to_string() }
  }
}


