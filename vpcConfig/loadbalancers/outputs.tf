output "lb_dns" {
  value = aws_lb.master_lb.dns_name
}

output "alb_sg" {
  value = aws_security_group.nlb_sg.id
}