template "blog-web-prod.json" do
  app,role,env = name.sub('.json','').split('-')
  source "web.json.erb"
  variables(
    env: env,
    app: app,
    role: role,
    ami: "ami-4836a428", # us-west-2
    instance_type: "t2.small",
    port: "80",
    high_threshold: "35",
    high_periods: "4",
    low_threshold: "20",
    low_periods: "2",
    max_size: "6",
    min_size: "3",
    down_adjustment: "-1",
    up_adjustment: "2"
  )
end
